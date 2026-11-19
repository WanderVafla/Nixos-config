--!strict
-- The round dot disc of the mockup's music card: 9 rings of dots around an accent center dot.
-- Dots are stacked in a column, each in its own row, and moved to their place on the ring with
-- translateX/Y. A row still takes its dot's height, so every dot is shifted back up by the height
-- of the rows above it.

local M = {}

export type Style = {
	size: number, -- disc diameter, px
	color: string, -- even rings
	dimColor: string, -- odd rings
	accent: string, -- center dot and the marked dots on the outer ring
}

local RINGS = 9

-- Pattern from the mockup: a dot shows when this wave is above the ring's threshold.
local function wave(angle: number, ring: number): number
	return 0.5 + 0.5 * math.sin(angle * 3 + ring) * math.cos(angle * 5 - ring * 0.7)
end

-- levels[r] in 0..1 scales ring r (1 = as in the mockup); phase rotates the pattern.
function M.render(style: Style, levels: { number }, phase: number)
	local s = style.size / 300 -- the mockup drew the disc on a 300 px canvas
	local center = style.size / 2
	local dotSize = math.max(2, math.floor(5.2 * s + 0.5))
	local nodes = {}
	local stacked = 0 -- layout height of the rows placed so far

	local function place(x: number, y: number, size: number, fill: string)
		table.insert(nodes, ui.row({ width = size, height = size }, {
			ui.box({
				width = size,
				height = size,
				radius = size / 2,
				fill = fill,
				translateX = x - size / 2,
				translateY = y - size / 2 - stacked,
			}),
		}))
		stacked += size
	end

	for ring = 0, RINGS - 1 do
		local r = (30 + ring * 14) * s
		local count = math.floor(2 * math.pi * (30 + ring * 14) / 11)
		local level = levels[ring + 1] or 1
		for k = 0, count - 1 do
			local angle = k / count * 2 * math.pi
			if wave(angle + phase, ring) * level >= ring / 11 then
				local fill = if ring == RINGS - 1 and k % 9 == 0
					then style.accent
					else (if ring % 2 == 1 then style.dimColor else style.color)
				place(center + r * math.cos(angle), center + r * math.sin(angle), dotSize, fill)
			end
		end
	end
	place(center, center, math.floor(12 * s + 0.5), style.accent)

	return ui.column({ width = style.size, height = style.size, gap = 0 }, nodes)
end

M.RINGS = RINGS

return M
