--!strict
-- Desktop widget: a round 25x25 dot matrix, like the Glyph Matrix of the Nothing Phone (3).
-- Ring k (distance from the center) shows band k: the louder the band, the more of the ring's
-- dots light up. Unlit dots stay faintly visible like LEDs that are off.

local channel = require("./channel.luau")

local SIZE = 25
local CENTER = (SIZE - 1) / 2
local RADIUS = SIZE / 2 - 0.1

local function conf(key: string, default: any): any
	local value = noctalia.getConfig(key)
	if value == nil then
		return default
	end
	return value
end

local pitch = conf("pitch", 10.0)
local dotScale = conf("dot_scale", 0.7)
local offOpacity = conf("off_opacity", 0.12)
local color = conf("color", "on_surface")
local accent = conf("accent_color", "error")

local dot = math.max(1, math.floor(pitch * dotScale + 0.5))
local gap = pitch - dot

-- Precompute each cell: inside the circle or not, its ring and a stable per-dot threshold, so a
-- ring fills up in a scattered pattern instead of sweeping around.
type Cell = { inside: boolean, ring: number, threshold: number }
local cells: { { Cell } } = {}
for y = 0, SIZE - 1 do
	local row: { Cell } = {}
	for x = 0, SIZE - 1 do
		local d = math.sqrt((x - CENTER) ^ 2 + (y - CENTER) ^ 2)
		local hash = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
		table.insert(row, {
			inside = d <= RADIUS,
			ring = math.min(channel.BANDS, math.floor(d) + 1),
			threshold = 0.08 + 0.85 * (hash - math.floor(hash)),
		})
	end
	table.insert(cells, row)
end

local function render(bands: { number }, active: boolean)
	local rows = {}
	for y = 1, SIZE do
		local boxes = {}
		for x = 1, SIZE do
			local cell = cells[y][x]
			local isCenter = cell.ring == 1
			local on = cell.inside and (isCenter or (active and (bands[cell.ring] or 0) > cell.threshold))
			table.insert(boxes, ui.box({
				width = dot,
				height = dot,
				radius = dot / 2,
				fill = if cell.inside then (if isCenter then accent else color) else "#00000000",
				opacity = if on then 1 else (if cell.inside then offOpacity else 0),
			}))
		end
		table.insert(rows, ui.row({ gap = gap }, boxes))
	end
	desktopWidget.render(ui.column({ gap = gap }, rows))
end

noctalia.state.watch(channel.FRAME, function(frame: any)
	if type(frame) == "table" and type(frame.bands) == "table" then
		render(frame.bands, frame.active == true)
	end
end)

local silent = {}
for i = 1, channel.BANDS do
	silent[i] = 0
end
render(silent, false)
