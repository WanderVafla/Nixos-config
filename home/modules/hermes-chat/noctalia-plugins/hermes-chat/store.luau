-- Keeps the current session id and the recent messages in the plugin's data dir, so the chat
-- survives a Noctalia restart. The full history stays on the server.

local M = {}

-- Older messages are dropped from the local copy; the panel never needs more.
M.MAX_MESSAGES = 100

export type Message = {
	role: "user" | "assistant",
	text: string,
	tools: { string }?,
}

export type Chat = {
	sessionId: string?,
	messages: { Message },
}

local function path(): string?
	local dir = noctalia.pluginDataDir()
	if dir == nil then
		return nil
	end
	return `{dir}/chat.json`
end

function M.load(): Chat
	local file = path()
	local text = if file ~= nil then noctalia.readFile(file) else nil
	if text == nil or text == "" then
		return { sessionId = nil, messages = {} }
	end
	local data = noctalia.json.decode(text)
	if type(data) ~= "table" then
		return { sessionId = nil, messages = {} }
	end
	return {
		sessionId = if type(data.sessionId) == "string" then data.sessionId else nil,
		messages = if type(data.messages) == "table" then data.messages else {},
	}
end

function M.trim(chat: Chat)
	local extra = #chat.messages - M.MAX_MESSAGES
	if extra > 0 then
		chat.messages = table.move(chat.messages, extra + 1, #chat.messages, 1, {})
	end
end

function M.save(chat: Chat)
	local file = path()
	if file == nil then
		return
	end
	M.trim(chat)
	local text = noctalia.json.encode({ sessionId = chat.sessionId, messages = chat.messages })
	if text ~= nil then
		local ok, err = noctalia.writeFile(file, text)
		if not ok then
			noctalia.log(`hermes-chat: saving chat failed: {err}`)
		end
	end
end

return M
