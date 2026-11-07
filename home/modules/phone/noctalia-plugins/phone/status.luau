-- Reads the key=value status files the widget is built from. Reading local files
-- keeps the widget free: it never wakes the phone itself.
--   phone-watch/status   reachability and Syncthing (phone-watch systemd service)
--   phone-notify/battery battery, pushed by the phone app (phone-notify daemon)

local M = {}

-- phone-watch runs every minute; older data means the service stopped.
local STALE_SECONDS = 180

local function readKeyValues(relativePath)
	local runtimeDir = noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp"
	local text = noctalia.readFile(`{runtimeDir}/{relativePath}`)
	if text == nil or text == "" then
		return nil
	end

	local values = {}
	for key, value in string.gmatch(text, "([%w_]+)=([^\n]*)") do
		values[key] = value
	end
	return values
end

function M.read()
	local watch = readKeyValues("phone-watch/status")
	if watch == nil then
		return nil
	end
	-- The phone app reports only on change, so battery data has no staleness limit.
	local battery = readKeyValues("phone-notify/battery") or {}

	local updated = tonumber(watch.updated) or 0
	local stale = noctalia.nowMs() / 1000 - updated > STALE_SECONDS

	return {
		online = watch.online == "1" and not stale,
		battery = tonumber(battery.level),
		charging = battery.charging == "1",
		temp = tonumber(battery.temp),
		lowBattery = tonumber(watch.low_battery) or 20,
		syncConnected = watch.sync_connected == "1",
		syncCompletion = tonumber(watch.sync_completion),
		updated = updated,
	}
end

return M
