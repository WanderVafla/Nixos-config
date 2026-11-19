# dot-notify

Noctalia plugin `vladyslav/dot-notify`: a bar widget that shows a dot and the number of
notifications that arrived since you last clicked it, like the Nothing-style mockup (`● 3`).

| File | Responsibility |
|---|---|
| `noctalia-plugins/catalog.toml` | Catalog of this local plugin source |
| `dot-notify/plugin.toml` | Manifest: counter service, bar widget and its settings |
| `dot-notify/service.luau` | Counts `Notify` calls on the session bus, polls Do Not Disturb, keeps the count in the plugin data dir |
| `dot-notify/widget.luau` | Dot, count and tooltip; a click resets the count and opens the notification list |
| `dot-notify/channel.luau` | Shared state keys between the service and the widget |
| `dot-notify/translations/en.json` | Setting labels |

## How it works

- Plugins cannot read Noctalia's notification history (it is stored encrypted), so the service
  counts on its own: `dbus-monitor --session` on `org.freedesktop.Notifications.Notify`.
- The count resets only when you click the widget. Dismissing notifications inside the
  Noctalia panel does not lower it.
- A click runs `noctalia msg panel-toggle control-center notifications`.
- A right click toggles Do Not Disturb (`noctalia msg notification-dnd-toggle`); while it is on,
  the widget shows `bell-off` instead of the dot.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `dot_color` | error | Dot color while there are unseen notifications |
| `show_count` | true | Number next to the dot |

## Setting up

The plugin source, the enabled flag and the bar layout live in Noctalia's state:

```sh
noctalia msg plugins source add dotnotify path ~/.config/nixos/home/modules/dot-notify/noctalia-plugins
noctalia msg plugins enable vladyslav/dot-notify
noctalia msg config-set widget.dot-notify '{ type = "vladyslav/dot-notify:dot" }'
```

Then put `dot-notify` in place of `notifications` in the bar (Noctalia settings or
`bar.default.end`). `noctalia/config.toml` already does this for the default bar.

Test without notify-send:

```sh
busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications \
  org.freedesktop.Notifications Notify susssasa{sv}i test 0 "" "Title" "Body" 0 0 3000
```

Rollback: put `notifications` back into the bar and `noctalia msg plugins disable vladyslav/dot-notify`.
