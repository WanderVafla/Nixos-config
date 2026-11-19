--!strict
-- Counts notifications since the last reset: listens to Notify calls on the session bus and keeps
-- the number in a file, so it survives a Noctalia restart. Also polls the Do Not Disturb state.

local channel = require("./channel.luau")

local countFile = noctalia.pluginDataDir() .. "/unseen"
local saved = noctalia.readFile(countFile)
local unseen = tonumber(saved or "") or 0
local dnd = false

local function publish()
	noctalia.state.set(channel.COUNT, { unseen = unseen, dnd = dnd })
	noctalia.writeFile(countFile, tostring(unseen))
end

-- dbus-monitor prints one header line per call; the arguments follow on the next lines.
noctalia.runStream(
	"dbus-monitor --session \"type='method_call',interface='org.freedesktop.Notifications',member='Notify'\"",
	function(line: string)
		if string.find(line, "member=Notify", 1, true) then
			unseen += 1
			publish()
		end
	end
)

local function pollDnd()
	noctalia.runAsync("noctalia msg notification-dnd-status", function(result)
		if result.exitCode == 0 and result.stdout then
			local now = string.match(result.stdout, "^%s*(%a+)") == "on"
			if now ~= dnd then
				dnd = now
				publish()
			end
		end
	end)
end

local function onRequest(request: any)
	if type(request) ~= "table" then
		return
	end
	if request.kind == "reset" then
		unseen = 0
		publish()
	elseif request.kind == "toggle-dnd" then
		noctalia.runAsync("noctalia msg notification-dnd-toggle", function(_result)
			pollDnd()
		end)
	end
end

noctalia.setUpdateInterval(15000)

function update()
	pollDnd()
end

noctalia.state.watch(channel.REQUEST, onRequest)
publish()
pollDnd()
