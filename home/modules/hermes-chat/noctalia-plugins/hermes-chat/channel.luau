-- Shared state keys between the service (which owns the chat and the deploy status) and the
-- panel and bar widget (which only show them and send requests).
--   VIEW     written by the service: messages, sessions, status, pending approval, last error
--   DEPLOY   written by the service: the latest homelab-deploy-status JSON, or its error
--   REQUEST  written by the panel: one action for the service, tagged with a unique nonce

local M = {}

M.VIEW = "hermes-chat.view"
M.DEPLOY = "hermes-chat.deploy"
M.REQUEST = "hermes-chat.request"

local counter = 0

-- kind: "send" (fields.text), "approve" (fields.choice), "new", "switch" (fields.id),
-- "panel-opened" (refresh sessions and deploy), "refresh-deploy" or "watch-deploy" (poll faster).
function M.request(kind: string, fields: { [string]: any }?)
	counter += 1
	local request = fields or {}
	request.kind = kind
	-- The nonce lets the service tell two identical requests apart.
	request.nonce = `{noctalia.nowMs()}-{counter}-{math.random(1, 1000000000)}`
	noctalia.state.set(M.REQUEST, request)
end

return M
