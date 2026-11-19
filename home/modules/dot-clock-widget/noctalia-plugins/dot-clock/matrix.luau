--!strict
-- Turns a string into a ui tree of dots, one ui.box per grid cell.

local M = {}

export type Style = {
	pitch: number, -- distance between two dot centers, px
	dotScale: number, -- dot diameter relative to pitch
	charGap: number, -- empty cells between characters
	color: string,
	colonColor: string,
	hideColon: boolean,
}

local function glyphNode(rows: { string }, style: Style, color: string, hidden: boolean)
	local dot = math.max(1, math.floor(style.pitch * style.dotScale + 0.5))
	local gap = style.pitch - dot
	local rowNodes = {}
	for _, row in ipairs(rows) do
		local cells = {}
		for i = 1, #row do
			local on = string.sub(row, i, i) == "#" and not hidden
			-- Empty cells keep their place in the grid but draw nothing.
			table.insert(cells, ui.box({
				width = dot,
				height = dot,
				radius = dot / 2,
				fill = if on then color else "#00000000",
			}))
		end
		table.insert(rowNodes, ui.row({ gap = gap }, cells))
	end
	return ui.column({ gap = gap }, rowNodes)
end

function M.line(text: string, glyphs: { [string]: { string } }, style: Style)
	local dot = math.max(1, math.floor(style.pitch * style.dotScale + 0.5))
	-- Center distance between the last dot of one character and the first of the next.
	local between = (1 + style.charGap) * style.pitch - dot
	local nodes = {}
	for i = 1, #text do
		local ch = string.sub(text, i, i)
		local rows = glyphs[ch]
		if rows then
			local isColon = ch == ":"
			table.insert(nodes, glyphNode(
				rows,
				style,
				if isColon then style.colonColor else style.color,
				isColon and style.hideColon
			))
		end
	end
	return ui.row({ gap = between, align = "end" }, nodes)
end

return M
