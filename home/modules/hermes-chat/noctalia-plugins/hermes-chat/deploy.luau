-- Polls the homelab deploy status over SSH (homelab-deploy-status-remote) and publishes it
-- under channel.DEPLOY. Read-only: approving happens in a terminal with sudo (see panel.luau).

local channel = require("./channel.luau")

local M = {}

local COMMAND = "homelab-deploy-status-remote"
local POLL_MS = 60 * 1000
-- After the owner starts an approval, poll faster so the panel shows the deploy finishing.
local FAST_POLL_MS = 10 * 1000
local FAST_FOR_MS = 5 * 60 * 1000

local inFlight = false
local lastPollMs = -POLL_MS
local fastUntilMs = 0

local function publish(status: any, err: string?)
	local previous = noctalia.state.get(channel.DEPLOY)
	noctalia.state.set(channel.DEPLOY, {
		-- Keep showing the last known status while the server is unreachable.
		status = status or (if type(previous) == "table" then previous.status else nil),
		error = err,
		checkedAtMs = noctalia.nowMs(),
	})
end

function M.refresh()
	if inFlight then
		return
	end
	inFlight = true
	lastPollMs = noctalia.nowMs()
	noctalia.runAsync({ COMMAND }, function(result)
		inFlight = false
		if result.exitCode ~= 0 then
			local details = noctalia.string.trim(result.stderr)
			publish(nil, if details ~= "" then details else `exit code {result.exitCode}`)
			return
		end
		local status = noctalia.json.decode(result.stdout)
		if type(status) ~= "table" then
			publish(nil, "The server returned no valid JSON.")
			return
		end
		publish(status, nil)
	end, 30000)
end

function M.pollFast()
	fastUntilMs = noctalia.nowMs() + FAST_FOR_MS
end

-- Called from the service's update() tick.
function M.tick()
	local now = noctalia.nowMs()
	local interval = if now < fastUntilMs then FAST_POLL_MS else POLL_MS
	if now - lastPollMs >= interval then
		M.refresh()
	end
end

return M
