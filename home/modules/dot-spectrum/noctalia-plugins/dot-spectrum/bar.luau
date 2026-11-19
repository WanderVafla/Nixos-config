--!strict
-- Bar widget: a small dot equalizer. It is also the only place Noctalia delivers the audio
-- spectrum to, so it relays every frame to the desktop widgets through the plugin state.
-- When the laptop hears nothing, the phone's own spectrum (sent by the phone-notify daemon as
-- the IPC event "phone-spectrum") takes over; without that, while a player is playing, a
-- made-up spectrum from synth.luau keeps the widgets moving. Real local audio always wins.

local channel = require("./channel.luau")
local synth = require("./synth.luau")

local COLUMNS = 7
local ROWS = 4
local DOT = 3
local GAP = 1
local FRAME_MS = 50 -- relay and redraw at most 20 times a second
local IDLE_MS = 1000 -- how often to check for a playing player while nothing moves
local REAL_GRACE_MS = 400 -- real audio or a phone frame this recent keeps the next source off

local color = noctalia.getConfig("color") or "on_surface"
local simulate = noctalia.getConfig("simulate_when_silent") ~= false
local lastFrame = 0
local lastRealAudio = -REAL_GRACE_MS
local lastPhoneFrame = -REAL_GRACE_MS
local synthesizing = false

local function parse(values: string): { number }
	local bands = {}
	for value in string.gmatch(values, "[^,]+") do
		table.insert(bands, math.clamp(tonumber(value) or 0, 0, 1))
	end
	while #bands < channel.BANDS do
		table.insert(bands, 0)
	end
	return bands
end

local function render(bands: { number }, active: boolean)
	local columns = {}
	for c = 1, COLUMNS do
		-- Sample the bands evenly across the columns.
		local band = bands[math.floor((c - 1) * (#bands - 1) / (COLUMNS - 1)) + 1] or 0
		local lit = if active then math.floor(band * ROWS + 0.5) else 0
		local dots = {}
		for r = ROWS, 1, -1 do
			table.insert(dots, ui.box({
				width = DOT,
				height = DOT,
				radius = DOT / 2,
				fill = color,
				opacity = if r <= math.max(lit, 1) then 1 else 0.2,
			}))
		end
		table.insert(columns, ui.column({ gap = GAP }, dots))
	end
	barWidget.render(ui.row({ gap = GAP, align = "end" }, columns))
end

local function relay(bands: { number }, active: boolean)
	noctalia.state.set(channel.FRAME, { bands = bands, active = active })
	render(bands, active)
end

function onAudioSpectrum(values: string, state: string)
	local now = noctalia.nowMs()
	-- state is "<audio active>,<a player is playing>", each "1" or "0".
	local active = string.sub(state, 1, 1) == "1"
	if active then
		lastRealAudio = now
	elseif synthesizing or now - lastPhoneFrame < REAL_GRACE_MS then
		return -- the silent frames would fight the phone's or the made-up ones
	end
	if now - lastFrame < FRAME_MS then
		return
	end
	lastFrame = now
	relay(parse(values), active)
end

-- Spectrum frames of music playing on the phone, about 20 a second while it plays.
function onIpc(event: string, payload: string)
	if event ~= "phone-spectrum" then
		return
	end
	local now = noctalia.nowMs()
	if now - lastRealAudio < REAL_GRACE_MS then
		return
	end
	lastPhoneFrame = now
	if now - lastFrame < FRAME_MS then
		return
	end
	lastFrame = now
	relay(parse(payload), true)
end

local function playerPlaying(): boolean
	local player = noctalia.mediaPlayer()
	return player ~= nil and player.status == "Playing"
end

-- Runs every IDLE_MS, or every FRAME_MS while the made-up spectrum is on.
function update()
	local now = noctalia.nowMs()
	local heard = now - lastRealAudio < REAL_GRACE_MS or now - lastPhoneFrame < REAL_GRACE_MS
	local want = simulate and not heard and playerPlaying()
	if want then
		relay(synth.frame(now), true)
	elseif synthesizing and not heard then
		relay(table.create(channel.BANDS, 0), false) -- music stopped: settle the dots
	end
	if want ~= synthesizing then
		synthesizing = want
		noctalia.setUpdateInterval(if want then FRAME_MS else IDLE_MS)
	end
end

noctalia.setUpdateInterval(IDLE_MS)

local empty = {}
for i = 1, channel.BANDS do
	empty[i] = 0
end
render(empty, false)
