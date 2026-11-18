-- Background service that owns the chat: it creates the Hermes session, streams each reply over
-- SSH (hermes-chat-remote), switches between sessions, keeps the messages and publishes them for
-- the panel and bar widget. It also drives the deploy status poller (deploy.luau).
-- It lives as long as Noctalia, so a reply keeps arriving while the panel is closed.

local channel = require("./channel.luau")
local deploy = require("./deploy.luau")
local protocol = require("./protocol.luau")
local sessions = require("./sessions.luau")
local store = require("./store.luau")

local REMOTE = "hermes-chat-remote"
local ID_PATTERN = sessions.ID_PATTERN
local MAX_ERROR_LINES = 20

local chat = store.load()
-- Desktop chats on the server, newest first; nil until the first successful listing.
type Session = { id: string, title: string, lastActive: number? } -- same shape as sessions.Session
local sessionList: { Session }? = nil

-- What the panel shows besides the messages.
local status: "idle" | "thinking" | "loading" | "approval" | "error" = "idle"
local activeTool: string? = nil
local approval: { [string]: any }? = nil
local lastError: string? = nil

local busy = false
local dirty = true
local revision = 0
local lastNonce: string? = nil

-- Per-reply state while a stream runs.
type Message = { role: string, text: string, tools: { string }? } -- same shape as store.Message
local reply: Message? = nil
local errorLines: { string } = {}
local completed = false

local function shellQuote(value: string): string
	return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local function markDirty()
	dirty = true
end

-- Copies the messages: state values are snapshots, and the reply keeps changing in place.
local function publish()
	revision += 1
	local messages = {}
	for i, message in chat.messages do
		messages[i] = { role = message.role, text = message.text, tools = message.tools }
	end
	noctalia.state.set(channel.VIEW, {
		messages = messages,
		sessionId = chat.sessionId,
		sessions = sessionList or {},
		status = status,
		tool = activeTool,
		approval = approval,
		error = lastError,
		busy = busy,
		revision = revision,
	})
	dirty = false
end

local function refreshSessions()
	sessions.list(function(list, err)
		if list == nil then
			noctalia.log(`hermes-chat: listing sessions failed: {err}`)
			return
		end
		sessionList = list
		markDirty()
	end)
end

local function fail(message: string)
	lastError = message
	status = "error"
	busy = false
	activeTool = nil
	approval = nil
	markDirty()
end

local function addTool(name: string)
	if reply == nil then
		return
	end
	local tools = reply.tools or {}
	if not table.find(tools, name) then
		table.insert(tools, name)
	end
	reply.tools = tools
end

local function onEvent(name: string, data: { [string]: any })
	if reply == nil then
		return
	end
	if name == "assistant.delta" and type(data.delta) == "string" then
		reply.text ..= data.delta
		activeTool = nil
	elseif name == "tool.started" then
		activeTool = data.tool_name or "tool"
		addTool(activeTool :: string)
	elseif name == "tool.completed" or name == "tool.failed" then
		activeTool = nil
	elseif name == "approval.request" then
		approval = {
			runId = data.run_id,
			command = data.command,
			description = data.description,
			choices = data.choices,
		}
		status = "approval"
	elseif name == "assistant.completed" then
		-- The final text is authoritative: deltas can miss pieces the agent rewrote.
		if type(data.content) == "string" and data.content ~= "" then
			reply.text = data.content
		end
	elseif name == "run.completed" then
		completed = true
	elseif name == "run.failed" or name == "run.cancelled" or name == "run.interrupted" then
		completed = true
		lastError = if type(data.error) == "string" then data.error else `Hermes: {name}`
	elseif name == "error" and type(data.message) == "string" then
		lastError = data.message
	end
	markDirty()
end

local function finishReply(exitCode: number)
	busy = false
	activeTool = nil
	approval = nil

	if exitCode ~= 0 and not completed then
		local details = table.concat(errorLines, "\n")
		lastError = if details ~= "" then details else `hermes-chat-remote exited with code {exitCode}`
		-- The server forgot the session (e.g. its database was reset): start a new one next time.
		if string.find(string.lower(details), "not found", 1, true) then
			chat.sessionId = nil
		end
	end

	if reply ~= nil and reply.text == "" then
		reply.text = if lastError ~= nil then "_No reply._" else "_Empty reply._"
	end
	status = if lastError ~= nil then "error" else "idle"
	reply = nil
	store.save(chat)
	markDirty()
	-- A new session appears in the list, and an old one may have a new title.
	refreshSessions()
end

local function onStreamLine(line: string)
	local parsed = protocol.parse(line)
	if parsed.kind == "event" then
		onEvent(parsed.name, parsed.data)
	elseif parsed.kind == "exit" then
		finishReply(parsed.code)
	elseif #errorLines < MAX_ERROR_LINES and parsed.text ~= "" then
		table.insert(errorLines, parsed.text)
	end
end

local function streamReply(sessionId: string, text: string)
	local dir = noctalia.pluginDataDir()
	if dir == nil then
		fail("No plugin data directory for the outgoing message.")
		return
	end
	-- The message goes over stdin, so it never passes through a shell command line.
	local outbox = `{dir}/outbox.txt`
	local ok, err = noctalia.writeFile(outbox, text)
	if not ok then
		fail(`Could not write the message: {err}`)
		return
	end

	local command = REMOTE .. " send " .. sessionId .. " < " .. shellQuote(outbox)
		.. " 2>&1; printf '" .. protocol.EXIT_MARKER .. "\\t%s\\n' \"$?\""
	if not noctalia.runStream(command, onStreamLine) then
		fail("Could not start hermes-chat-remote.")
	end
end

-- Calls back with the session id, creating a session on the server when there is none yet.
local function withSession(onReady: (sessionId: string) -> ())
	if chat.sessionId ~= nil then
		onReady(chat.sessionId)
		return
	end
	noctalia.runAsync({ REMOTE, "new" }, function(result)
		local id = noctalia.string.trim(result.stdout)
		if result.exitCode ~= 0 or not string.match(id, ID_PATTERN) then
			local details = noctalia.string.trim(result.stderr .. "\n" .. result.stdout)
			fail(`Could not create a Hermes session. {details}`)
			return
		end
		chat.sessionId = id
		store.save(chat)
		onReady(id)
	end, 30000)
end

local function send(text: string)
	text = noctalia.string.trim(text)
	if busy or text == "" then
		return
	end
	busy = true
	completed = false
	errorLines = {}
	lastError = nil
	status = "thinking"

	table.insert(chat.messages, { role = "user", text = text })
	reply = { role = "assistant", text = "" }
	table.insert(chat.messages, reply :: any)
	store.trim(chat)
	markDirty()

	withSession(function(sessionId)
		streamReply(sessionId, text)
	end)
end

local function answerApproval(choice: string)
	if approval == nil or not table.find(approval.choices or {}, choice) then
		return
	end
	local runId = approval.runId
	if type(runId) ~= "string" or not string.match(runId, ID_PATTERN) then
		fail("The approval request has no valid run id.")
		return
	end
	approval = nil
	status = "thinking"
	markDirty()
	noctalia.runAsync({ REMOTE, "approve", runId, choice }, function(result)
		if result.exitCode ~= 0 then
			noctalia.notifyError("Hermes: answering the approval failed", noctalia.string.trim(result.stderr))
		end
	end, 30000)
end

local function newChat()
	if busy then
		return
	end
	chat = { sessionId = nil, messages = {} }
	lastError = nil
	status = "idle"
	store.save(chat)
	markDirty()
end

-- Loads another session's history from the server; the chat is locked until it arrives.
local function switchSession(id: string)
	if busy or id == chat.sessionId or not string.match(id, ID_PATTERN) then
		return
	end
	busy = true
	status = "loading"
	lastError = nil
	chat = { sessionId = id, messages = {} }
	markDirty()
	sessions.messages(id, function(messages, err)
		busy = false
		-- Another switch or a new chat may have happened meanwhile.
		if chat.sessionId ~= id then
			return
		end
		if messages == nil then
			fail(`Could not load the chat: {err}`)
			return
		end
		chat.messages = messages
		status = "idle"
		store.save(chat)
		markDirty()
	end)
end

local function onRequest(request: any)
	if type(request) ~= "table" or request.nonce == lastNonce then
		return
	end
	lastNonce = request.nonce
	if request.kind == "send" and type(request.text) == "string" then
		send(request.text)
	elseif request.kind == "approve" and type(request.choice) == "string" then
		answerApproval(request.choice)
	elseif request.kind == "new" then
		newChat()
	elseif request.kind == "switch" and type(request.id) == "string" then
		switchSession(request.id)
	elseif request.kind == "panel-opened" then
		refreshSessions()
		deploy.refresh()
	elseif request.kind == "refresh-deploy" then
		deploy.refresh()
	elseif request.kind == "watch-deploy" then
		deploy.pollFast()
	end
end

-- A request left over from before a plugin reload must not be sent again.
local pending = noctalia.state.get(channel.REQUEST)
if type(pending) == "table" then
	lastNonce = pending.nonce
end
noctalia.state.watch(channel.REQUEST, onRequest)

refreshSessions()

-- Deltas arrive many times a second; publishing on a tick keeps the panel from re-rendering per token.
noctalia.setUpdateInterval(100)

-- Hooks
function update()
	if dirty then
		publish()
	end
	deploy.tick()
end
