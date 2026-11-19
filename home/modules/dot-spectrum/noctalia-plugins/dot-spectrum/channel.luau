--!strict
-- Shared state between the bar widget (which receives the spectrum) and the desktop matrix.
--   FRAME  written by the bar widget: { bands: { number }, active: boolean }

local M = {}

M.FRAME = "dot-spectrum.frame"
M.BANDS = 13 -- one band per matrix ring, bass in the center

return M
