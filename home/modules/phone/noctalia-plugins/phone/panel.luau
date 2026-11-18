-- Panel opened from the bar widget: phone details and quick actions.
-- Actions call the phone-* scripts installed by home/modules/phone (adb.nix, notify.nix).

local status = require("./status.luau")

noctalia.setUpdateInterval(5000)

local function statBox(glyph, text, subtext)
	return ui.column({
		fill = "surface_variant",
		flexGrow = 1,
		radius = 8,
		align = "center",
		padding = 10,
		gap = 4,
	}, {
		ui.glyph({ name = glyph, size = 24 }),
		ui.label({ text = text, fontWeight = "bold" }),
		ui.label({ text = subtext, fontSize = 12, color = "on_surface_variant" }),
	})
end

local function syncText(s)
	if not s.syncConnected then
		return "offline"
	end
	if s.syncCompletion == nil then
		return "connected"
	end
	return `{s.syncCompletion}%`
end

-- Modes each toggle button cycles through, in click order.
local DND_MODES = {
	{ id = "off", text = "DND off", glyph = "bell" },
	{ id = "priority", text = "Priority", glyph = "star" },
	{ id = "silence", text = "Silence", glyph = "moon" },
}

local RINGER_MODES = {
	{ id = "normal", text = "Sound", glyph = "volume" },
	{ id = "vibrate", text = "Vibrate", glyph = "vibration" },
	{ id = "silent", text = "Silent", glyph = "volume-off" },
}

local LOCK_MODES = {
	{ id = "off", text = "Auto-lock off", glyph = "lock-open" },
	{ id = "tailscale", text = "Lock: Tailscale", glyph = "network" },
	{ id = "bluetooth", text = "Lock: Bluetooth", glyph = "bluetooth" },
}

local function modeIndex(modes, id)
	for i, mode in modes do
		if mode.id == id then
			return i
		end
	end
	-- Unknown modes (e.g. DND "alarms") show as the first one; a click moves on from there.
	return 1
end

local function nextMode(modes, id)
	return modes[modeIndex(modes, id) % #modes + 1]
end

-- Shows the current mode; highlighted whenever it is not the default (first) one.
local function toggleButton(modes, id, onClick)
	local index = modeIndex(modes, id)
	local mode = modes[index]
	return ui.button({
		text = mode.text,
		glyph = mode.glyph,
		flexGrow = 1,
		variant = if index == 1 then "outline" else "primary",
		onClick = onClick,
	})
end

local function bluetoothRow(s)
	local text = if not s.bluetooth
		then "Off"
		elseif s.btDevices ~= "" then s.btDevices
		else "On, nothing connected"
	return ui.row({ gap = 8, align = "center" }, {
		ui.glyph({ name = if s.bluetooth then "bluetooth" else "bluetooth-off", size = 18 }),
		ui.label({ text = text, flexGrow = 1 }),
		ui.button({
			text = if s.bluetooth then "Turn off" else "Turn on",
			variant = "outline",
			onClick = "onBluetoothToggle",
		}),
	})
end

local function nearText(s)
	if s.lockMode == "off" then
		return ""
	elseif s.near == true then
		return "phone near"
	elseif s.near == false then
		return "phone away"
	end
	return "checking…"
end

local function deviceControls(s)
	return ui.column({ gap = 6 }, {
		bluetoothRow(s),
		ui.row({ gap = 8 }, {
			toggleButton(DND_MODES, s.dnd, "onDndCycle"),
			toggleButton(RINGER_MODES, s.ringer, "onRingerCycle"),
		}),
		ui.row({ gap = 8, align = "center" }, {
			toggleButton(LOCK_MODES, s.lockMode, "onLockModeCycle"),
			ui.label({ text = nearText(s), fontSize = 12, color = "on_surface_variant" }),
		}),
	})
end

local function render()
	local s = status.read()
	local online = s ~= nil and s.online

	local stats
	if online then
		stats = ui.row({ gap = 8 }, {
			statBox(
				if s.charging then "battery-charging" else "battery",
				if s.battery ~= nil then `{s.battery}%` else "?",
				if s.charging then "charging" else "battery"
			),
			statBox("temperature", if s.temp ~= nil then `{s.temp}°C` else "?", "temperature"),
			statBox("folders", syncText(s), "Syncthing"),
		})
	else
		stats = ui.label({
			text = "Phone is unreachable over Tailscale.",
			color = "on_surface_variant",
		})
	end

	panel.render(ui.column({ gap = 8 }, {
		ui.row({ justify = "space_between", align = "center" }, {
			ui.label({ text = "Nothing Phone (3)", fontSize = 16 }),
			ui.label({
				text = if online then "online" else "offline",
				fontSize = 12,
				color = if online then "primary" else "error",
			}),
		}),
		ui.separator({ thickness = 2, orientation = "horizontal", spacing = 4 }),
		stats,
		ui.separator({ thickness = 2, orientation = "horizontal", spacing = 4 }),
		if online then deviceControls(s) else ui.spacer({ height = 0 }),
		ui.separator({ thickness = 2, orientation = "horizontal", spacing = 4 }),
		ui.row({ gap = 8 }, {
			ui.button({ text = "Screen", glyph = "cast", flexGrow = 1, variant = "primary", onClick = "onScreenClicked" }),
			ui.button({ text = "Connect", glyph = "plug-connected", flexGrow = 1, variant = "outline", onClick = "onConnectClicked" }),
		}),
		ui.row({ gap = 8 }, {
			ui.button({ text = "Screenshot", glyph = "screenshot", flexGrow = 1, variant = "outline", onClick = "onScreenshotClicked" }),
			ui.button({ text = "~/Phone", glyph = "folder", flexGrow = 1, variant = "outline", onClick = "onFolderClicked" }),
		}),
	}))
end

-- Hooks
function onOpen(_ctx)
	render()
end

function update()
	render()
end

-- Click handlers
function onScreenClicked()
	panel.close()
	-- scrcpy keeps running, so detach it instead of waiting for it.
	noctalia.runAsync("setsid -f phone-screen >/dev/null 2>&1")
end

function onConnectClicked()
	noctalia.runAsync("phone-connect", function(res)
		if res.exitCode ~= 0 then
			noctalia.notifyError("Phone: connect failed")
		end
		render()
	end)
end

function onScreenshotClicked()
	noctalia.runAsync("phone-screenshot", function(res)
		if res.exitCode ~= 0 then
			noctalia.notifyError("Phone: screenshot failed")
		end
	end)
end

-- The phone reports its new state right after a change; re-render once it lands.
local function sendCommand(path)
	noctalia.runAsync(`phone-command {path}`, function(res)
		if res.exitCode ~= 0 then
			noctalia.notifyError(`Phone: {path} failed`)
		end
		render()
	end)
end

function onBluetoothToggle()
	local s = status.read()
	local target = if s ~= nil and s.bluetooth then "off" else "on"
	noctalia.runAsync(`phone-bluetooth {target}`, function(res)
		if res.exitCode ~= 0 then
			noctalia.notifyError(`Phone: Bluetooth {target} failed`)
		end
		render()
	end)
end

-- The daemon owns the mode and the next status check picks it up.
function onLockModeCycle()
	noctalia.runAsync("phone-lock-mode next", function(res)
		if res.exitCode ~= 0 then
			noctalia.notifyError("Phone: changing auto-lock failed")
		end
		render()
	end)
end

function onDndCycle()
	local s = status.read()
	if s ~= nil then
		sendCommand(`dnd/{nextMode(DND_MODES, s.dnd).id}`)
	end
end

function onRingerCycle()
	local s = status.read()
	if s ~= nil then
		sendCommand(`ringer/{nextMode(RINGER_MODES, s.ringer).id}`)
	end
end

function onFolderClicked()
	panel.close()
	noctalia.runInTerminal("yazi ~/Phone")
end
