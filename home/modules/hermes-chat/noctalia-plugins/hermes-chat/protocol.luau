-- Parses the lines of a `hermes-chat-remote send` stream.
--   "<event name>\t<json>"  one Hermes SSE event (see hermes-chat on the server)
--   "__exit\t<code>"        appended by the service once the command ends
--   anything else           stderr text from ssh, curl or an HTTP error body

local M = {}

M.EXIT_MARKER = "__exit"

export type Line =
	{ kind: "event", name: string, data: { [string]: any } }
	| { kind: "exit", code: number }
	| { kind: "text", text: string }

function M.parse(line: string): Line
	local name, rest = string.match(line, "^([%w%._]+)\t(.*)$")
	if name == M.EXIT_MARKER then
		return { kind = "exit", code = tonumber(rest) or 1 }
	end
	if name ~= nil then
		local data = noctalia.json.decode(rest)
		if type(data) == "table" then
			return { kind = "event", name = name, data = data }
		end
	end
	return { kind = "text", text = line }
end

return M
