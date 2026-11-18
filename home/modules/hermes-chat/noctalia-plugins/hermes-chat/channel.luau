-- Shared state keys between the service (which owns the chat) and the panel and bar widget
-- (which only show it and send requests).
--   VIEW     written by the service: messages, status, pending approval, last error
--   REQUEST  written by the panel: one action for the service, tagged with a unique nonce

local M = {}

M.VIEW = "hermes-chat.view"
M.REQUEST = "hermes-chat.request"

local counter = 0

-- kind: "send" (fields.text), "approve" (fields.choice) or "new".
function M.request(kind: string, fields: { [string]: any }?)
	counter += 1
	local request = fields or {}
	request.kind = kind
	-- The nonce lets the service tell two identical requests apart.
	request.nonce = `{noctalia.nowMs()}-{counter}-{math.random(1, 1000000000)}`
	noctalia.state.set(M.REQUEST, request)
end

return M
