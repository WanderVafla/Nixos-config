-- Bar widget: phone icon colored by connection state, battery percentage next to it.

local status = require("./status.luau")

noctalia.setUpdateInterval(5000)

local function showOffline()
	barWidget.setGlyph("device-mobile-off")
	barWidget.setGlyphColor("on_surface_variant")
	barWidget.setText("")
	barWidget.setTooltip("Phone offline")
end

-- Hooks
function update()
	local s = status.read()
	if s == nil or not s.online then
		showOffline()
		return
	end

	local color = "on_surface"
	if s.battery ~= nil and s.battery < s.lowBattery and not s.charging then
		color = "error"
	end

	barWidget.setGlyph(if s.charging then "device-mobile-charging" else "device-mobile")
	barWidget.setGlyphColor(color)
	barWidget.setColor(color)
	barWidget.setText(if s.battery ~= nil then `{s.battery}%` else "")
	barWidget.setTooltip(if s.charging then "Phone online, charging" else "Phone online")
end

function onClick()
	noctalia.togglePanel("vladyslav/phone:panel")
end
