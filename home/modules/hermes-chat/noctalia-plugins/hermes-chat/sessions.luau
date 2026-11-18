-- Reads the server's chat sessions over SSH: the list of desktop chats and the messages of one.

local M = {}

local REMOTE = "hermes-chat-remote"
-- Same rule as hermes-chat on the server: ids end up in a remote shell command line.
M.ID_PATTERN = "^[%w_%-]+$"

export type Session = { id: string, title: string, lastActive: number? }

local function decodeArray(result: any): ({ any }?, string?)
	if result.exitCode ~= 0 then
		local details = noctalia.string.trim(result.stderr .. "\n" .. result.stdout)
		return nil, if details ~= "" then details else `exit code {result.exitCode}`
	end
	local data = noctalia.json.decode(result.stdout)
	if type(data) ~= "table" then
		return nil, "The server returned no valid JSON."
	end
	return data, nil
end

-- Newest first, as the server returns them.
function M.list(onDone: (sessions: { Session }?, err: string?) -> ())
	noctalia.runAsync({ REMOTE, "sessions" }, function(result)
		local data, err = decodeArray(result)
		if data == nil then
			onDone(nil, err)
			return
		end
		local sessions = {}
		for _, item in data do
			if type(item.id) == "string" and string.match(item.id, M.ID_PATTERN) then
				table.insert(sessions, {
					id = item.id,
					title = if type(item.title) == "string" and item.title ~= "" then item.title else item.id,
					lastActive = tonumber(item.lastActive),
				})
			end
		end
		onDone(sessions, nil)
	end, 30000)
end

-- Messages as { role, text, tools }, already reduced to user and assistant text by the server.
function M.messages(id: string, onDone: (messages: { any }?, err: string?) -> ())
	if not string.match(id, M.ID_PATTERN) then
		onDone(nil, "Invalid session id.")
		return
	end
	noctalia.runAsync({ REMOTE, "messages", id }, function(result)
		local data, err = decodeArray(result)
		if data == nil then
			onDone(nil, err)
			return
		end
		local messages = {}
		for _, item in data do
			if (item.role == "user" or item.role == "assistant") and type(item.text) == "string" then
				table.insert(messages, {
					role = item.role,
					text = item.text,
					tools = if type(item.tools) == "table" and #item.tools > 0 then item.tools else nil,
				})
			end
		end
		onDone(messages, nil)
	end, 30000)
end

return M
