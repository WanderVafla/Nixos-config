# phone

Home Manager module that integrates the laptop with the phone (Nothing Phone 3)
over Tailscale: ADB and scrcpy, Syncthing, notifications, battery, media and
the proximity lock, all shown in a Noctalia bar widget.

The phone side is the [phone-notify](../../../../../Projects/phone-notify) Android app;
its daemon is pulled in through the `phone-notify` flake input.

## Files

| File | Responsibility |
|---|---|
| [`default.nix`](default.nix) | Imports the parts and declares the `phone.*` options |
| [`adb.nix`](adb.nix) | ADB over Tailscale, scrcpy and the `phone-*` helper scripts |
| [`syncthing.nix`](syncthing.nix) | Syncthing device and shared folders |
| [`watch.nix`](watch.nix) | `phone-watch` timer: reachability and Syncthing status for the widget |
| [`notify.nix`](notify.nix) | `phone-notify` daemon: notifications, battery, media, proximity lock |
| [`noctalia-plugins/`](noctalia-plugins) | Local Noctalia plugin source with the `vladyslav/phone` widget and panel |

## Options

All under `phone.*`, defined in `default.nix`:

| Option | Default | Meaning |
|---|---|---|
| `host` | `100.79.194.71` | Tailscale IP of the phone (an IP, so it works without MagicDNS) |
| `adbPort` | `5555` | Port adbd listens on after `adb tcpip` |
| `syncthingId` | phone's device ID | Syncthing device ID; `null` disables folder sharing |
| `lowBattery` | `20` | Battery percentage that triggers a warning |
| `notifyPort` | `47100` | Port of the `phone-notify` daemon on the laptop |
| `mediaPort` | `47101` | Port of the phone app's command server (fixed in the app) |
| `proximityLock.mode` | `off` | Default lock mode: `off`, `tailscale` or `bluetooth` |
| `proximityLock.minRssi` | `-75` | Weakest BLE beacon signal (dBm) that counts as near |
| `proximityLock.interval` | `15` | Seconds between proximity checks |
| `proximityLock.scanTime` | `6` | Seconds each Bluetooth check scans; must be shorter than `interval` |
| `proximityLock.awayChecks` | `3` | Consecutive "away" checks before locking |

## Commands

| Command | From | What it does |
|---|---|---|
| `phone-adb-wifi` | `adb.nix` | With the phone on USB: brings up Tailscale and switches adbd to TCP; only needed when Wireless debugging is off (see below) |
| `phone-connect` | `adb.nix` | Connects ADB over the network (re-enabling TCP mode if on USB) and refreshes the widget |
| `phone-screen` | `adb.nix` | Mirrors the screen with scrcpy |
| `phone-screenshot` | `adb.nix` | Saves a screenshot to `~/Pictures/Phone` |
| `phone-bluetooth on\|off` | `adb.nix` | Switches the phone's Bluetooth through ADB |
| `phone-command <path>` | `notify.nix` | Sends a command to the phone app, e.g. `dnd/off`, `ringer/vibrate`, `media/next`, `sync` |
| `phone-lock-mode [next\|off\|tailscale\|bluetooth]` | `notify.nix` | Prints or sets the proximity lock mode |
| `phone-watch` | `watch.nix` | Collects status once; normally run by the timer every minute |

`ANDROID_SERIAL` is set to `host:adbPort`, so `adb` targets the phone without `-s`.
The `phone-notify` daemon keeps that address working: every minute it checks it,
and when the phone refuses it (adbd restarted, e.g. after a reboot) it finds the
Wireless debugging port, runs `adb tcpip adbPort` through it and reconnects.
This needs Wireless debugging left on in the phone's developer options. The
current address and its state are in `$XDG_RUNTIME_DIR/phone-notify/adb`.

## Services

| Unit | Kind | Role |
|---|---|---|
| `phone-notify.service` | user service | HTTP daemon on `notifyPort`; receives data from the phone app |
| `phone-watch.timer` / `.service` | timer, every minute | Writes reachability and Syncthing state; asks the phone to resync when it comes back online |
| `syncthing.service` | user service | File sync with the phone |

The `phone-notify` port is reachable only over Tailscale: `tailscale0` is the
only trusted firewall interface (see `configuration.nix`).

## Syncthing folders

| Folder ID | Laptop path | Phone path |
|---|---|---|
| `phone` | `~/Phone` | set in the Syncthing-Fork app |
| `obsidian-synclive` | `~/Documents/Valut/SyncLive` | `/sdcard/Documents/Obsidian/SyncLive` |

`overrideDevices` and `overrideFolders` are on: devices and folders come only
from `syncthing.nix`, and changes made in the GUI are reverted. A folder the
phone offers is rejected until it is added here, with the same folder ID.

The vault's `.stignore` is generated too. It keeps per-device Obsidian state
(`workspace*.json`) and `.trash` out of sync, so switching devices does not
create conflicts.

## Widget data

The Noctalia plugin only reads local files, so it never wakes the phone:

| File (under `$XDG_RUNTIME_DIR`) | Written by | Content |
|---|---|---|
| `phone-watch/status` | `phone-watch` | Online, Syncthing connection and completion, low battery threshold |
| `phone-notify/battery` | `phone-notify` | Level, charging, temperature |
| `phone-notify/device` | `phone-notify` | Bluetooth, Do Not Disturb, ringer mode |
| `phone-notify/lock` | `phone-notify` | Lock mode and whether the phone is near |
| `phone-notify/recent.json` | `phone-notify` | Latest notifications |

Noctalia loads the plugin straight from `noctalia-plugins/` (a `path` plugin
source in `~/.local/state/noctalia/settings.toml`), so edits to the `.luau`
files apply without a rebuild. Keep `catalog.toml` in sync with `plugin.toml`.

## State outside Nix

| What | Where |
|---|---|
| Shared token (secret, never in the Nix store) | `~/.config/phone-notify/token`, generated on first activation |
| Lock mode chosen at runtime | `~/.local/state/phone-notify/lock-mode` |
| Plugin enabled and widget placement | `~/.local/state/noctalia/settings.toml` |
| Tailscale login | Tailscale state; `tailscale up` once |
| Phone app, its permissions and settings | on the phone |

## Setting up a new machine

1. `home-manager switch --flake ~/.config/nixos#vladyslav`
2. `tailscale up` and sign in.
3. Install the phone-notify app and enter `http://<laptop Tailscale IP>:47100` and the token from `~/.config/phone-notify/token`.
4. In Syncthing-Fork, add the laptop's device ID and share the folders listed above.
5. On the phone, set the battery usage of phone-notify and Syncthing-Fork to **Unrestricted**.

## Troubleshooting

| Symptom | Check |
|---|---|
| Widget battery is stale | `curl -m5 http://127.0.0.1:47100/health`; no answer means the daemon is stuck: `systemctl --user restart phone-notify` |
| Widget shows offline | `tailscale ping <host>`; `systemctl --user status phone-watch.timer` |
| Syncthing does not connect | Is Syncthing-Fork running on the phone (its run conditions: Wi-Fi only, charging only)? `adb shell ss -ltn \| grep 22000` |
| A folder from the phone is ignored | Its folder ID is missing in `syncthing.nix`; look for `Unexpected folder ID` in `journalctl --user -u syncthing` |
| ADB lost after a phone reboot | Wait up to a minute for the daemon to reconnect; `cat $XDG_RUNTIME_DIR/phone-notify/adb` and `journalctl --user -u phone-notify`. If Wireless debugging is off, turn it on, or plug in by USB and run `phone-adb-wifi` |
