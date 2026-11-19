--!strict
-- Parses the Dot Clock glyph file: blocks that start with "= <char>" followed by rows of
-- "#" (dot) and "." (empty). "# " lines are comments. Same format as fonts/dot-clock/glyphs.txt.

local M = {}

export type Glyphs = { [string]: { string } }

function M.parse(text: string): Glyphs
	local glyphs: Glyphs = {}
	local current: string? = nil
	for raw in string.gmatch(text .. "\n", "(.-)\r?\n") do
		local line = string.match(raw, "^%s*(.-)%s*$") or ""
		if string.sub(line, 1, 1) == "=" then
			local name = string.match(line, "^=%s*(.-)$") or ""
			current = if name == "space" then " " else name
			glyphs[current :: string] = {}
		elseif line ~= "" and string.sub(line, 1, 2) ~= "# " and current ~= nil then
			table.insert(glyphs[current :: string], line)
		end
	end
	return glyphs
end

return M
