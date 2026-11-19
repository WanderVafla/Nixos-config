--!strict
-- Shared state keys between the counter service and the bar widget.
--   COUNT    written by the service: { unseen: number, dnd: boolean }
--   REQUEST  written by the widget: { kind = "reset" | "toggle-dnd", nonce = ... }

local M = {}

M.COUNT = "dot-notify.count"
M.REQUEST = "dot-notify.request"

local counter = 0

function M.request(kind: string)
	counter += 1
	-- The nonce lets the service tell two identical requests apart.
	noctalia.state.set(M.REQUEST, { kind = kind, nonce = `{noctalia.nowMs()}-{counter}` })
end

return M
