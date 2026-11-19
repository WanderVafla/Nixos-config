--!strict
-- Made-up spectrum for music the laptop cannot hear (it plays on the phone or on another
-- Spotify Connect device). Not tied to the real sound: each band drifts on two slow waves, and
-- a soft beat of about 116 bpm swells the bass bands.

local channel = require("./channel.luau")

local M = {}

local BEAT_HZ = 1.93

-- One pair of wave speeds and offsets per band, fixed so the motion never repeats visibly.
type Band = { w1: number, w2: number, p1: number, p2: number }
local bands: { Band } = {}
for i = 1, channel.BANDS do
	bands[i] = {
		w1 = 0.9 + 0.37 * i,
		w2 = 2.3 + 0.61 * ((i * 7) % 5),
		p1 = i * 1.7,
		p2 = i * 0.9,
	}
end

-- Bands in 0..1 for the moment tMs (any monotonic clock in milliseconds).
function M.frame(tMs: number): { number }
	local t = tMs / 1000
	local beat = math.max(0, math.sin(2 * math.pi * BEAT_HZ * t)) ^ 4
	local out = {}
	for i, band in bands do
		local tilt = (i - 1) / (channel.BANDS - 1) -- 0 for bass, 1 for treble
		local base = 0.5 - 0.25 * tilt
		local drift = 0.18 * math.sin(t * band.w1 + band.p1) + 0.1 * math.sin(t * band.w2 + band.p2)
		out[i] = math.clamp(base + drift + 0.35 * beat * (1 - tilt), 0, 1)
	end
	return out
end

return M
