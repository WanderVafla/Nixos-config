-- Panel shell: a tab bar on top (Chat, Deploy) and the active tab below.
-- The tabs live in chat_view.luau and deploy_view.luau; this file only switches between them.

local channel = require("./channel.luau")
local chatView = require("./chat_view.luau")
local deployView = require("./deploy_view.luau")

local tab: "chat" | "deploy" = "chat"
local render: () -> ()

local function tabButton(id: "chat" | "deploy", text: string, glyph: string, attention: boolean)
	return ui.button({
		text = text,
		glyph = glyph,
		controlSize = "sm",
		variant = if tab == id then "primary" elseif attention then "destructive" else "ghost",
		onClick = function()
			tab = id
			if id == "deploy" then
				channel.request("refresh-deploy")
			end
			render()
		end,
	})
end

render = function()
	local view = chatView.currentView()
	local deploy = deployView.current()
	local statusText, statusColor = chatView.status(view)
	local deployWaiting = deployView.isWaiting(deploy)

	local header = ui.row({ gap = 6, align = "center" }, {
		tabButton("chat", "Chat", "message-circle", view.status == "approval"),
		tabButton("deploy", if deployWaiting then "Deploy •" else "Deploy", "shield-check", deployWaiting),
		ui.label({
			text = if tab == "chat" then statusText else "",
			fontSize = 12,
			color = statusColor,
			flexGrow = 1,
			textAlign = "end",
		}),
		ui.button({
			glyph = "close",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Close",
			onClick = function()
				panel.close()
			end,
		}),
	})

	local children = { header, ui.separator({ thickness = 1, orientation = "horizontal", spacing = 2 }) }
	local body = if tab == "chat" then chatView.render(view) else deployView.render(deploy)
	for _, child in body do
		table.insert(children, child)
	end
	panel.render(ui.column({ gap = 8, flexGrow = 1 }, children))
end

noctalia.state.watch(channel.VIEW, function(_view)
	render()
end)
noctalia.state.watch(channel.DEPLOY, function(_deploy)
	render()
end)

-- Hooks
function onOpen(_context)
	-- Titles change after each reply and other chats may have started; the deploy may have moved on.
	channel.request("panel-opened")
	-- Open straight on the deploy tab when something waits for approval.
	if deployView.isWaiting(deployView.current()) then
		tab = "deploy"
	end
	render()
end
