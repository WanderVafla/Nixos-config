-- Chat panel: messages rendered as Markdown, a pending approval with its buttons, and the input.
-- It only shows the service's view and sends requests to it (see channel.luau).

local channel = require("./channel.luau")

local APPROVAL_BUTTONS = {
	{ choice = "once", text = "Allow once", variant = "primary" },
	{ choice = "session", text = "Allow for session", variant = "outline" },
	{ choice = "deny", text = "Deny", variant = "destructive" },
}

local STATUS_TEXT = {
	idle = "ready",
	thinking = "thinking…",
	approval = "waiting for you",
	error = "error",
}

-- A fresh key clears the input after sending and focuses it again.
local inputRevision = 0
local draft = ""

local function currentView(): { [string]: any }
	local view = noctalia.state.get(channel.VIEW)
	if type(view) == "table" then
		return view
	end
	return { messages = {}, status = "idle", busy = false, revision = 0 }
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

local function header(view: { [string]: any })
	local statusColor = if view.status == "error" or view.status == "approval"
		then "error"
		elseif view.busy then "primary"
		else "on_surface_variant"
	return ui.row({ gap = 8, align = "center" }, {
		ui.glyph({ name = "message-circle", size = 20, color = "primary" }),
		ui.label({ text = "Hermes", fontSize = 16, fontWeight = "semibold" }),
		ui.label({ text = STATUS_TEXT[view.status] or view.status, fontSize = 12, color = statusColor, flexGrow = 1 }),
		ui.button({
			glyph = "trash",
			variant = "ghost",
			tooltip = "New chat",
			enabled = not view.busy,
			onClick = function()
				channel.request("new")
			end,
		}),
		ui.button({
			glyph = "close",
			variant = "ghost",
			tooltip = "Close",
			onClick = function()
				panel.close()
			end,
		}),
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

local function render()
	local view = currentView()

	local messages = {}
	for index, message in view.messages do
		table.insert(messages, messageBubble(index, message, view))
	end
	if #messages == 0 then
		table.insert(messages, ui.label({
			text = "Ask Hermes anything. Replies support Markdown.",
			color = "on_surface_variant",
		}))
	end

	local children = {
		header(view),
		ui.separator({ thickness = 1, orientation = "horizontal", spacing = 2 }),
		ui.scroll({
			key = "messages",
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
	table.insert(children, ui.row({ gap = 6, align = "end" }, {
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
				if not currentView().busy then
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
	}))

	panel.render(ui.column({ gap = 8, flexGrow = 1 }, children))
end

noctalia.state.watch(channel.VIEW, function(_view)
	render()
end)

-- Hooks
function onOpen(_context)
	render()
end
