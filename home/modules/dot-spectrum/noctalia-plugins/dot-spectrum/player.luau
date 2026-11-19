--!strict
-- Desktop widget: the music card of the Nothing-style mockup. A dot disc that reacts to the audio
-- (frames relayed by the bar widget), then the player name, the title in Doto Round, the artist,
-- a dot progress bar with the playhead in the accent color, and the times.

local channel = require("./channel.luau")
local disc = require("./disc.luau")

local function conf(key: string, default: any): any
	local value = noctalia.getConfig(key)
	if value == nil then
		return default
	end
	return value
end

local discSize = conf("disc_size", 240.0)
local color = conf("color", "on_surface")
local dimColor = conf("dim_color", "on_surface_variant")
local accent = conf("accent_color", "error")
local titleFont = conf("title_font", "Doto Round")
local textFont = conf("text_font", "Space Mono")

local PROGRESS_DOTS = 30
local FRAME_MS = 50

local levels: { number } = {}
for i = 1, disc.RINGS do
	levels[i] = 1
end
local active = false
local phase = 0.0
local lastRender = 0

local function clock(ms: number): string
	local total = math.max(0, math.floor(ms / 1000))
	return string.format("%d:%02d", total // 60, total % 60)
end

local function progressDots(fraction: number)
	local dots = {}
	local head = math.floor(fraction * (PROGRESS_DOTS - 1) + 0.5)
	for i = 0, PROGRESS_DOTS - 1 do
		table.insert(dots, ui.box({
			width = 7,
			height = 7,
			radius = 3.5,
			fill = if i == head then accent else color,
			opacity = if i < head then 1 else (if i == head then 1 else 0.25),
		}))
	end
	return ui.row({ gap = 5 }, dots)
end

local function render()
	local player = noctalia.mediaPlayer()
	local text = {}
	if player ~= nil and player.title ~= nil and player.title ~= "" then
		local who = string.upper(player.identity or "player")
		local artists = if type(player.artists) == "table" then table.concat(player.artists, ", ") else ""
		local byline = artists .. (if player.album ~= nil and player.album ~= "" then " — " .. player.album else "")
		local length = player.lengthMs or 0
		local position = player.positionMs or 0
		local fraction = if length > 0 then math.clamp(position / length, 0, 1) else 0
		local status = if player.status == "Playing" then "NOW PLAYING" else string.upper(player.status or "")
		text = {
			ui.label({ text = status .. " · " .. who, fontFamily = textFont, fontSize = 11, color = dimColor }),
			ui.label({ text = string.upper(player.title), fontFamily = titleFont, fontSize = 40, color = color, maxLines = 2, maxWidth = 360 }),
			ui.label({ text = byline, fontFamily = textFont, fontSize = 13, color = dimColor, maxLines = 1, maxWidth = 360 }),
			ui.spacer({ height = 18 }),
			progressDots(fraction),
			ui.row({ justify = "space_between", width = 30 * 7 + 29 * 5 }, {
				ui.label({ text = clock(position), fontFamily = textFont, fontSize = 11, color = dimColor }),
				ui.label({ text = if length > 0 then clock(length) else "--:--", fontFamily = textFont, fontSize = 11, color = dimColor }),
			}),
		}
	else
		text = {
			ui.label({ text = "NOTHING PLAYING", fontFamily = textFont, fontSize = 11, color = dimColor }),
		}
	end

	desktopWidget.render(ui.row({
		gap = 28,
		align = "center",
		padding = 22,
		radius = 18,
		fill = "surface",
		border = "outline_variant",
		borderWidth = 1,
	}, {
		disc.render({ size = discSize, color = color, dimColor = dimColor, accent = accent }, levels, phase),
		ui.column({ gap = 6, align = "start" }, text),
	}))
end

-- Audio frames from the bar widget: map the 13 bands onto the 9 rings, bass in the middle.
noctalia.state.watch(channel.FRAME, function(frame: any)
	if type(frame) ~= "table" or type(frame.bands) ~= "table" then
		return
	end
	active = frame.active == true
	for ring = 1, disc.RINGS do
		local band = frame.bands[math.floor((ring - 1) * (channel.BANDS - 1) / (disc.RINGS - 1)) + 1] or 0
		-- Silence shows the mockup pattern; music thins and swells each ring with its band.
		levels[ring] = if active then 0.45 + 1.1 * band else 1
	end
	if active then
		phase += 0.015
	end
	local now = noctalia.nowMs()
	if now - lastRender >= FRAME_MS then
		lastRender = now
		render()
	end
end)

noctalia.setUpdateInterval(1000)

function update()
	-- Keeps the progress and the times moving while no audio frames arrive (paused, muted).
	render()
end

render()
