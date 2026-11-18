-- Bar widget: chat icon that shows whether Hermes is answering or waits for an approval.

local channel = require("./channel.luau")

local function show(view: any)
	if type(view) ~= "table" then
		view = { status = "idle", busy = false }
	end

	local color = "on_surface"
	local tooltip = "Hermes: ready"
	if view.status == "approval" then
		color = "error"
		tooltip = "Hermes waits for your approval"
	elseif view.status == "error" then
		color = "error"
		tooltip = "Hermes: the last message failed"
	elseif view.busy then
		color = "primary"
		tooltip = if view.tool ~= nil then `Hermes is using {view.tool}` else "Hermes is thinking"
	end

	barWidget.setGlyph("message-circle")
	barWidget.setGlyphColor(color)
	barWidget.setTooltip(tooltip)
end

noctalia.state.watch(channel.VIEW, show)
show(noctalia.state.get(channel.VIEW))

-- Hooks
function onClick()
	noctalia.togglePanel("vladyslav/hermes-chat:panel")
end
