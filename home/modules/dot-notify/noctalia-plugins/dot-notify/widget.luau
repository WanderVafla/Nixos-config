--!strict
-- Bar widget: a dot that turns red with a count when notifications arrived since the last click.
-- A click resets the count and opens the notifications tab of the control center.

local channel = require("./channel.luau")

local function conf(key: string, default: any): any
	local value = noctalia.getConfig(key)
	if value == nil then
		return default
	end
	return value
end

local dotColor = conf("dot_color", "error")
local showCount = conf("show_count", true)

local function show()
	local state = noctalia.state.get(channel.COUNT)
	local unseen = if type(state) == "table" then state.unseen or 0 else 0
	local dnd = type(state) == "table" and state.dnd == true

	if dnd then
		barWidget.setGlyph("bell-off")
		barWidget.setGlyphColor("on_surface_variant")
	else
		barWidget.setGlyph("point-filled")
		barWidget.setGlyphColor(if unseen > 0 then dotColor else "on_surface_variant")
	end
	barWidget.setText(if showCount and unseen > 0 then tostring(unseen) else "")

	local tip = if unseen == 1 then "1 new notification" else `{unseen} new notifications`
	if dnd then
		tip ..= "\nDo Not Disturb is on"
	end
	barWidget.setTooltip(tip)
end

noctalia.state.watch(channel.COUNT, function(_state)
	show()
end)
show()

-- Hooks
function onClick()
	channel.request("reset")
	noctalia.runAsync("noctalia msg panel-toggle control-center notifications", function(_result) end)
end
