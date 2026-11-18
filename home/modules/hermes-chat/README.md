# hermes-chat

Home Manager module and Noctalia plugin to chat with the Hermes agent on the
homelab server and to watch its deploys. Replies stream in and render as
Markdown. When Hermes wants to run a dangerous command, the panel shows its
approval request with buttons. The panel has two tabs:

- **Chat**: switch between desktop chats (a select on top) or start a new one.
- **Deploy**: what the homelab deployer is doing, the commits and protected
  files waiting for approval, a link to the diff, and an approve button that
  opens a terminal with `sudo homelab-deploy approve`.

```
Noctalia plugin ──runStream──▶ hermes-chat-remote ──ssh──▶ hermes-chat (server) ──▶ Hermes API (container)
```

The SSH login is the authorization: `API_SERVER_KEY` stays on the server
(`modules/base/hermes-chat` in `homelab-nixos-config`), and nothing secret is
stored on this machine.

## Files

| File | Responsibility |
|---|---|
| [`default.nix`](default.nix) | `hermesChat.sshHost` option and the SSH wrappers: `hermes-chat-remote`, `homelab-deploy-status-remote`, `homelab-deploy-approve` |
| [`noctalia-plugins/`](noctalia-plugins) | Local Noctalia plugin source with `vladyslav/hermes-chat` |
| `hermes-chat/plugin.toml` | Manifest: service, bar widget, panel |
| `hermes-chat/service.luau` | Owns the chat: session, SSH streams, switching, approvals, persistence |
| `hermes-chat/sessions.luau` | Lists the server's desktop chats and loads one chat's messages |
| `hermes-chat/deploy.luau` | Polls the deploy status (every minute, every 10 s after an approval) |
| `hermes-chat/protocol.luau` | Parses the `event<TAB>json` lines of the stream |
| `hermes-chat/store.luau` | Saves the session id and recent messages |
| `hermes-chat/channel.luau` | Shared state keys between the service, panel and widget |
| `hermes-chat/panel.luau` | Panel shell: tab bar and the active tab |
| `hermes-chat/chat_view.luau` | Chat tab: session select, Markdown messages, approval box, input |
| `hermes-chat/deploy_view.luau` | Deploy tab: state, pending commits and files, approve and diff buttons |
| `hermes-chat/widget.luau` | Bar icon colored by chat and deploy status |

## How it works

- The **service** runs as long as Noctalia does. A reply keeps arriving while
  the panel is closed, and the bar icon turns `primary` while Hermes works.
- The panel and the widget only read `hermes-chat.view` from `noctalia.state`.
  They send actions through `hermes-chat.request`.
- Each message goes to `hermes-chat-remote send <session>` through stdin, so the
  message text never passes through a shell command line.
- SSH reuses one connection for 10 minutes (`ControlPersist`), so only the
  first message pays for the handshake.
- Approval answers are limited to `once`, `session` and `deny`. A permanent
  `always` is not offered.
- Deploy approval is deliberately not one click: the button opens a terminal
  running `ssh -t homelab sudo homelab-deploy approve`, so the sudo password
  and the y/N prompt stay a separate barrier from the SSH key.
- The session list shows only desktop chats (`source=api_server`); Telegram
  sessions belong to the Hermes gateway and are not continued here.
- The chat is its own Hermes session and does not mix with Telegram.

## State outside Nix

| What | Where |
|---|---|
| Session id and last 100 messages | `~/.local/state/noctalia/plugins/data/vladyslav/hermes-chat/chat.json` (plugin data dir) |
| Full history | Hermes on the server |
| Plugin source, enabled state, bar placement | `~/.local/state/noctalia/settings.toml` |

## Setting up

1. Deploy the server side (homelab PRs #31–#33), then check `ssh homelab 'hermes-chat sessions'` and `ssh homelab homelab-deploy-status`.
2. `home-manager switch --flake ~/.config/nixos#vladyslav`
3. Register the plugin source and enable the plugin:
   ```sh
   noctalia msg plugins source add hermes path ~/.config/nixos/home/modules/hermes-chat/noctalia-plugins
   noctalia msg plugins enable vladyslav/hermes-chat
   ```
4. Add the `hermes-chat` widget to the bar in Noctalia settings.

Edits to the `.luau` files apply without a rebuild. Keep `catalog.toml` in sync
with `plugin.toml`.

## Troubleshooting

| Symptom | Check |
|---|---|
| "Could not create a Hermes session" | `hermes-chat-remote new` in a terminal; with a passphrase-protected key, the key must be in ssh-agent (BatchMode never prompts) |
| Reply stops halfway | The SSH connection dropped and Hermes interrupted the run; send again |
| Session not found | The service starts a new session on the next message |
| Deploy tab: "Could not read the deploy status" | `homelab-deploy-status-remote` in a terminal |
| Approve terminal closes at once | `homelab-deploy-approve` in a terminal; the sudo password is asked on the server |
| Panel looks stale | `journalctl --user -u noctalia` or `~/.cache/noctalia/noctalia.log`, look for `hermes-chat` |
