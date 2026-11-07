-- Panel opened from the bar widget: phone details and quick actions.
-- Actions call the phone-* scripts installed by home/modules/phone/adb.nix.

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

function onFolderClicked()
	panel.close()
	noctalia.runInTerminal("yazi ~/Phone")
end
