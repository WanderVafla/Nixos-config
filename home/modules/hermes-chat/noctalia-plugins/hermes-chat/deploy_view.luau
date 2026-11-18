-- Deploy tab of the panel: what the homelab deployer is doing, the commits and protected files
-- that wait for approval, and buttons to read the diff and approve. Approving opens a terminal
-- (homelab-deploy-approve), because it needs the sudo password and a y/N answer on the server.

local channel = require("./channel.luau")

local M = {}

local STATE_LOOK = {
	deployed = { text = "Deployed", glyph = "shield-check", color = "primary" },
	["awaiting-approval"] = { text = "Waiting for your approval", glyph = "alert-circle", color = "error" },
	failed = { text = "Deploy failed, rolled back", glyph = "circle-x", color = "error" },
}

local FILE_STATUS = { A = "added", M = "changed", D = "deleted", R = "renamed" }
local MAX_FILES = 30

function M.current(): { [string]: any }
	local deploy = noctalia.state.get(channel.DEPLOY)
	if type(deploy) == "table" then
		return deploy
	end
	return {}
end

function M.isWaiting(deploy: { [string]: any }): boolean
	return type(deploy.status) == "table" and deploy.status.state == "awaiting-approval"
end

local function short(rev: any): string
	return if type(rev) == "string" and rev ~= "" then string.sub(rev, 1, 7) else "—"
end

local function stateCard(status: { [string]: any })
	local look = STATE_LOOK[status.state]
		or { text = tostring(status.state), glyph = "alert-circle", color = "on_surface_variant" }
	local time = if type(status.time) == "string" then (string.gsub(string.sub(status.time, 1, 16), "T", " ")) else ""
	return ui.column({ gap = 4, padding = 10, radius = 10, fill = "surface_variant" }, {
		ui.row({ gap = 6, align = "center" }, {
			ui.glyph({ name = look.glyph, size = 18, color = look.color }),
			ui.label({ text = look.text, fontWeight = "bold", color = look.color, flexGrow = 1 }),
			ui.label({ text = `{time} UTC`, fontSize = 11, color = "on_surface_variant" }),
		}),
		ui.label({ text = `deployed: {short(status.deployed)}`, fontSize = 12, color = "on_surface_variant" }),
		if type(status.message) == "string" and status.message ~= ""
			then ui.label({ text = status.message, fontSize = 12, color = "on_surface_variant", maxLines = 3 })
			else ui.spacer({ height = 0 }),
	})
end

local function pendingDetails(status: { [string]: any })
	local rows = {}
	table.insert(rows, ui.label({ text = `Commits ({short(status.pending)})`, fontWeight = "semibold" }))
	for _, commit in status.commits or {} do
		table.insert(rows, ui.markdown({ text = `\`{commit.rev}\` {commit.subject}` }))
	end

	local files = status.files or {}
	table.insert(rows, ui.label({ text = `Protected files ({#files})`, fontWeight = "semibold" }))
	for i, file in files do
		if i > MAX_FILES then
			table.insert(rows, ui.label({ text = `… and {#files - MAX_FILES} more`, color = "on_surface_variant" }))
			break
		end
		table.insert(rows, ui.row({ gap = 6 }, {
			ui.label({ text = FILE_STATUS[file.status] or file.status, width = 64, fontSize = 12, color = "on_surface_variant" }),
			ui.label({ text = file.path, fontSize = 12, flexGrow = 1, maxLines = 1 }),
		}))
	end
	return ui.scroll({ key = "deploy-details", flexGrow = 1, gap = 4 }, rows)
end

local function actions(status: { [string]: any }?)
	local waiting = status ~= nil and status.state == "awaiting-approval"
	local compareUrl = if status ~= nil and type(status.compareUrl) == "string" then status.compareUrl else ""
	return ui.row({ gap = 6 }, {
		ui.button({
			text = "Approve in terminal",
			glyph = "shield-check",
			variant = "primary",
			flexGrow = 1,
			enabled = waiting,
			tooltip = "Opens ssh homelab sudo homelab-deploy approve",
			onClick = function()
				noctalia.runInTerminal("homelab-deploy-approve")
				channel.request("watch-deploy")
			end,
		}),
		ui.button({
			text = "Diff",
			variant = "outline",
			enabled = compareUrl ~= "",
			tooltip = "Open the compare page on GitHub",
			onClick = function()
				noctalia.runAsync({ "xdg-open", compareUrl })
			end,
		}),
		ui.button({
			glyph = "refresh",
			variant = "ghost",
			tooltip = "Check again",
			onClick = function()
				channel.request("refresh-deploy")
			end,
		}),
	})
end

function M.render(deploy: { [string]: any }): { any }
	local status = if type(deploy.status) == "table" then deploy.status else nil
	local children = {}
	if status == nil then
		table.insert(children, ui.label({
			text = if deploy.error ~= nil then "Could not read the deploy status." else "Checking the deploy status…",
			color = "on_surface_variant",
		}))
		table.insert(children, ui.spacer({ flexGrow = 1 }))
	else
		table.insert(children, stateCard(status))
		if type(status.pending) == "string" and status.pending ~= "" then
			table.insert(children, pendingDetails(status))
		else
			table.insert(children, ui.label({ text = "Nothing waits for approval.", color = "on_surface_variant" }))
			table.insert(children, ui.spacer({ flexGrow = 1 }))
		end
	end
	if type(deploy.error) == "string" then
		table.insert(children, ui.label({ text = deploy.error, color = "error", fontSize = 12, maxLines = 3 }))
	end
	table.insert(children, actions(status))
	return children
end

return M
