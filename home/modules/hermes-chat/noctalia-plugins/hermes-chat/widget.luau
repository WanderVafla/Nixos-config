-- Bar widget: chat icon that shows whether Hermes is answering, waits for a chat approval, or a
-- homelab deploy waits for the owner's approval.

local channel = require("./channel.luau")

local function show()
	local view = noctalia.state.get(channel.VIEW)
	if type(view) ~= "table" then
		view = { status = "idle", busy = false }
	end
	local deploy = noctalia.state.get(channel.DEPLOY)
	local deployWaiting = type(deploy) == "table"
		and type(deploy.status) == "table"
		and deploy.status.state == "awaiting-approval"

	local color = "on_surface"
	local lines = {}
	if view.status == "approval" then
		color = "error"
		table.insert(lines, "Hermes waits for your approval")
	elseif view.status == "error" then
		color = "error"
		table.insert(lines, "Hermes: the last message failed")
	elseif view.busy then
		color = "primary"
		table.insert(lines, if view.tool ~= nil then `Hermes is using {view.tool}` else "Hermes is thinking")
	else
		table.insert(lines, "Hermes: ready")
	end
	if deployWaiting then
		color = "error"
		table.insert(lines, "Deploy waits for approval")
	end

	barWidget.setGlyph("message-circle")
	barWidget.setGlyphColor(color)
	barWidget.setTooltip(table.concat(lines, "\n"))
end

noctalia.state.watch(channel.VIEW, function(_view)
	show()
end)
noctalia.state.watch(channel.DEPLOY, function(_deploy)
	show()
end)
show()

-- Hooks
function onClick()
	noctalia.togglePanel("vladyslav/hermes-chat:panel")
end
