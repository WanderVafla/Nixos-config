-- Chat tab of the panel: session switcher, messages rendered as Markdown, a pending approval with
-- its buttons, and the input. It only shows the service's view and sends requests (channel.luau).

local channel = require("./channel.luau")

local M = {}

local APPROVAL_BUTTONS = {
	{ choice = "once", text = "Allow once", variant = "primary" },
	{ choice = "session", text = "Allow for session", variant = "outline" },
	{ choice = "deny", text = "Deny", variant = "destructive" },
}

local STATUS_TEXT = {
	idle = "ready",
	thinking = "thinking…",
	loading = "loading…",
	approval = "waiting for you",
	error = "error",
}

local NEW_CHAT_TITLE = "New chat"

-- A fresh key clears the input after sending and focuses it again.
local inputRevision = 0
local draft = ""

function M.currentView(): { [string]: any }
	local view = noctalia.state.get(channel.VIEW)
	if type(view) == "table" then
		return view
	end
	return { messages = {}, sessions = {}, status = "idle", busy = false, revision = 0 }
end

-- The select lists the server's sessions; a chat not saved there yet shows as "New chat" on top.
local function sessionSwitcher(view: { [string]: any })
	local ids = {}
	local options = {}
	local selected = nil
	for _, session in view.sessions or {} do
		table.insert(ids, session.id)
		table.insert(options, session.title)
		if session.id == view.sessionId then
			selected = #ids - 1
		end
	end
	if selected == nil then
		table.insert(ids, 1, false)
		table.insert(options, 1, NEW_CHAT_TITLE)
		selected = 0
	end

	return ui.row({ gap = 6, align = "center" }, {
		ui.select({
			key = `sessions-{view.sessionId or "new"}`,
			options = options,
			selectedIndex = selected,
			flexGrow = 1,
			controlSize = "sm",
			enabled = not view.busy,
			onChange = function(index)
				local id = ids[(tonumber(index) or 0) + 1]
				if type(id) == "string" then
					channel.request("switch", { id = id })
				end
			end,
		}),
		ui.button({
			glyph = "message-circle",
			text = "New",
			variant = "outline",
			controlSize = "sm",
			tooltip = "Start a new chat",
			enabled = not view.busy,
			onClick = function()
				channel.request("new")
			end,
		}),
	})
end

local function messageBubble(index: number, message: { [string]: any }, view: { [string]: any })
	local isUser = message.role == "user"
	local text = message.text or ""
	local isLast = index == #view.messages

	local children = {}
	if not isUser and message.tools ~= nil and #message.tools > 0 then
		table.insert(children, ui.row({ gap = 4, align = "center" }, {
			ui.glyph({ name = "tool", size = 12, color = "on_surface_variant" }),
			ui.label({
				text = table.concat(message.tools, ", "),
				fontSize = 11,
				color = "on_surface_variant",
				maxLines = 1,
			}),
		}))
	end
	if text == "" and isLast and view.busy then
		local working = if view.tool ~= nil then `using {view.tool}…` else "thinking…"
		table.insert(children, ui.label({ text = working, color = "on_surface_variant" }))
	else
		table.insert(children, ui.markdown({ key = `md-{index}`, text = text }))
	end

	return ui.column({
		key = `msg-{index}`,
		gap = 4,
		padding = 10,
		radius = 10,
		fill = if isUser then "primary/0.14" else "surface_variant",
	}, children)
end

local function approvalBox(approval: { [string]: any })
	local buttons = {}
	for _, button in APPROVAL_BUTTONS do
		if table.find(approval.choices or {}, button.choice) then
			table.insert(buttons, ui.button({
				text = button.text,
				variant = button.variant,
				flexGrow = 1,
				onClick = function()
					channel.request("approve", { choice = button.choice })
				end,
			}))
		end
	end

	local command = if type(approval.command) == "string" then approval.command else ""
	local description = if type(approval.description) == "string" then approval.description else ""
	return ui.column({ gap = 6, padding = 10, radius = 10, fill = "error/0.12", border = "error/0.5", borderWidth = 1 }, {
		ui.row({ gap = 6, align = "center" }, {
			ui.glyph({ name = "shield-check", size = 18, color = "error" }),
			ui.label({ text = "Hermes asks for permission", fontWeight = "bold" }),
		}),
		if description ~= "" then ui.markdown({ text = description }) else ui.spacer({ height = 0 }),
		if command ~= "" then ui.markdown({ text = "```\n" .. command .. "\n```" }) else ui.spacer({ height = 0 }),
		ui.row({ gap = 6 }, buttons),
	})
end

local function submit(text: string)
	if noctalia.string.trim(text) == "" then
		return
	end
	channel.request("send", { text = text })
	draft = ""
	inputRevision += 1
end

local function inputRow(view: { [string]: any })
	return ui.row({ gap = 6, align = "end" }, {
		ui.input({
			key = `input-{inputRevision}`,
			flexGrow = 1,
			multiline = true,
			submitOnEnter = true,
			focus = true,
			placeholder = if view.busy then "Hermes is answering…" else "Message (Shift+Enter for a new line)",
			onChange = function(value)
				draft = value
			end,
			onSubmit = function(value)
				if not M.currentView().busy then
					submit(value)
				end
			end,
		}),
		ui.button({
			glyph = "send",
			variant = "primary",
			enabled = not view.busy,
			onClick = function()
				submit(draft)
			end,
		}),
	})
end

-- Text and color for the tab bar, so the panel header can show the chat state.
function M.status(view: { [string]: any }): (string, string)
	local color = if view.status == "error" or view.status == "approval"
		then "error"
		elseif view.busy then "primary"
		else "on_surface_variant"
	return STATUS_TEXT[view.status] or view.status, color
end

function M.render(view: { [string]: any }): { any }
	local messages = {}
	for index, message in view.messages do
		table.insert(messages, messageBubble(index, message, view))
	end
	if #messages == 0 then
		table.insert(messages, ui.label({
			text = if view.status == "loading" then "Loading the chat…" else "Ask Hermes anything. Replies support Markdown.",
			color = "on_surface_variant",
		}))
	end

	local children = {
		sessionSwitcher(view),
		ui.scroll({
			key = `messages-{view.sessionId or "new"}`,
			flexGrow = 1,
			gap = 8,
			stickToBottom = true,
			scrollToBottomRev = #view.messages,
		}, messages),
	}
	if view.approval ~= nil then
		table.insert(children, approvalBox(view.approval))
	end
	if view.status == "error" and type(view.error) == "string" then
		table.insert(children, ui.label({ text = view.error, color = "error", fontSize = 12, maxLines = 4 }))
	end
	table.insert(children, inputRow(view))
	return children
end

return M
