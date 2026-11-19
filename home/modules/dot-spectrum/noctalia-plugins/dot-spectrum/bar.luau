--!strict
-- Bar widget: a small dot equalizer. It is also the only place Noctalia delivers the audio
-- spectrum to, so it relays every frame to the desktop matrix through the plugin state.

local channel = require("./channel.luau")

local COLUMNS = 7
local ROWS = 4
local DOT = 3
local GAP = 1
local FRAME_MS = 50 -- relay and redraw at most 20 times a second

local color = noctalia.getConfig("color") or "on_surface"
local lastFrame = 0

local function parse(values: string): { number }
	local bands = {}
	for value in string.gmatch(values, "[^,]+") do
		table.insert(bands, math.clamp(tonumber(value) or 0, 0, 1))
	end
	while #bands < channel.BANDS do
		table.insert(bands, 0)
	end
	return bands
end

local function render(bands: { number }, active: boolean)
	local columns = {}
	for c = 1, COLUMNS do
		-- Sample the bands evenly across the columns.
		local band = bands[math.floor((c - 1) * (#bands - 1) / (COLUMNS - 1)) + 1] or 0
		local lit = if active then math.floor(band * ROWS + 0.5) else 0
		local dots = {}
		for r = ROWS, 1, -1 do
			table.insert(dots, ui.box({
				width = DOT,
				height = DOT,
				radius = DOT / 2,
				fill = color,
				opacity = if r <= math.max(lit, 1) then 1 else 0.2,
			}))
		end
		table.insert(columns, ui.column({ gap = GAP }, dots))
	end
	barWidget.render(ui.row({ gap = GAP, align = "end" }, columns))
end

function onAudioSpectrum(values: string, state: string)
	local now = noctalia.nowMs()
	if now - lastFrame < FRAME_MS then
		return
	end
	lastFrame = now
	local bands = parse(values)
	-- state is "<audio active>,<a player is playing>", each "1" or "0".
	local active = string.sub(state, 1, 1) == "1"
	noctalia.state.set(channel.FRAME, { bands = bands, active = active })
	render(bands, active)
end

local empty = {}
for i = 1, channel.BANDS do
	empty[i] = 0
end
render(empty, false)
