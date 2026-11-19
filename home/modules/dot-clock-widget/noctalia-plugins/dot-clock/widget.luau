--!strict
-- Dot Clock desktop and lock screen widget: draws the time (and optionally the date) as dots.

local glyphsLib = require("./glyphs.luau")
local matrix = require("./matrix.luau")

local function conf(key: string, default: any): any
	local value = noctalia.getConfig(key)
	if value == nil then
		return default
	end
	return value
end

local config = {
	glyphsPath = conf("glyphs_path", "~/.config/nixos/home/modules/fonts/dot-clock/glyphs.txt"),
	pitch = conf("pitch", 12.0),
	dotScale = conf("dot_scale", 0.6),
	charGap = conf("char_gap", 1.0),
	layout = conf("layout", "horizontal"),
	align = conf("align", "left"),
	showSeconds = conf("show_seconds", false),
	showDate = conf("show_date", false),
	dateAlign = conf("date_align", 0.0),
	blinkColon = conf("blink_colon", false),
	color = conf("color", "on_surface"),
	colonColor = conf("colon_color", "on_surface"),
}

local text = noctalia.readFile(noctalia.expandPath(config.glyphsPath))
if not text then
	noctalia.log("dot-clock: cannot read " .. tostring(config.glyphsPath))
	noctalia.notifyError("Dot Clock", noctalia.tr("notify.glyphs"))
	return
end
local glyphs = glyphsLib.parse(text)

local lastKey = ""

local function render()
	local now = os.date("*t") :: any
	local time = string.format("%02d:%02d", now.hour, now.min)
	if config.showSeconds then
		time ..= string.format(":%02d", now.sec)
	end
	local hideColon = config.blinkColon and now.sec % 2 == 1
	local date = string.format("%02d.%02d.%02d", now.day, now.month, now.year % 100)

	-- Re-render only when something visible changed.
	local key = time .. (if hideColon then "h" else "") .. (if config.showDate then date else "")
	if key == lastKey then
		return
	end
	lastKey = key

	local style: matrix.Style = {
		pitch = config.pitch,
		dotScale = config.dotScale,
		charGap = config.charGap,
		color = config.color,
		colonColor = config.colonColor,
		hideColon = hideColon,
	}
	-- Horizontal: one line "HH:MM[:SS]". Vertical: hours, minutes and seconds stacked, no colons.
	local timeLines: { string } = { time }
	if config.layout == "vertical" then
		timeLines = { string.format("%02d", now.hour), string.format("%02d", now.min) }
		if config.showSeconds then
			table.insert(timeLines, string.format("%02d", now.sec))
		end
	end
	local lines = {}
	local timeWidth = 0
	for _, text in ipairs(timeLines) do
		table.insert(lines, matrix.line(text, glyphs, style))
		timeWidth = math.max(timeWidth, matrix.width(text, glyphs, style))
	end
	-- align lines up every line (time and date) on its left edge, center or right edge.
	local flexAlign = if config.align == "center" then "center" elseif config.align == "right" then "end" else "start"
	local timeBlock = ui.column({ gap = config.pitch, align = flexAlign }, lines)
	lines = { timeBlock }
	if config.showDate then
		local small = table.clone(style)
		small.pitch = config.pitch / 2
		small.hideColon = false
		-- date_align moves the date from the left edge (0) through the center (0.5) to the right edge (1).
		-- With left alignment, date_align still moves the date under the time.
		local offset = if config.align == "left"
			then (timeWidth - matrix.width(date, glyphs, small)) * config.dateAlign
			else 0
		table.insert(lines, ui.row({ gap = 0 }, {
			ui.box({ width = math.max(0, offset), height = 1, fill = "#00000000" }),
			matrix.line(date, glyphs, small),
		}))
	end
	desktopWidget.render(ui.column({ gap = config.pitch * 2, align = flexAlign }, lines))
end

noctalia.setUpdateInterval(1000)

function update()
	render()
end

render()
