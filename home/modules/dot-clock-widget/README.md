# dot-clock-widget

Noctalia plugin `vladyslav/dot-clock`: a dot-matrix clock for the desktop and the lock screen.
It draws every dot itself (one `ui.box` per grid cell) from the same grids as the Dot Clock
font, `home/modules/fonts/dot-clock/glyphs.txt`, so editing a digit there changes both.

| File | Responsibility |
|---|---|
| `noctalia-plugins/catalog.toml` | Catalog of this local plugin source |
| `dot-clock/plugin.toml` | Manifest: one `desktop_widget` entry and its settings |
| `dot-clock/widget.luau` | Reads the settings and the glyph file, renders once per second when the time changes |
| `dot-clock/glyphs.luau` | Parses `glyphs.txt` |
| `dot-clock/matrix.luau` | Turns a string into rows of dots |
| `dot-clock/translations/en.json` | Setting labels |

## Settings

Set per widget in the Noctalia widget editor (or in `noctalia/config.toml`):

| Key | Default | Meaning |
|---|---|---|
| `pitch` | 12 | Distance between two dot centers in pixels; sets the clock size |
| `dot_scale` | 0.6 | Dot diameter relative to `pitch` |
| `char_gap` | 1 | Empty grid cells between characters |
| `show_seconds` | false | Seconds after the minutes |
| `show_date` | false | Date under the time, at half the pitch |
| `blink_colon` | false | Hide the colon every other second |
| `color` / `colon_color` | on_surface | Palette roles; `error` gives a red colon |
| `glyphs_path` | fonts/dot-clock/glyphs.txt | Glyph file (advanced) |

Set `background_opacity = 0.0` on the widget to drop the default card behind it.

## Setting up

The plugin source and the enabled flag live in Noctalia's state, not in Nix:

```sh
noctalia msg plugins source add dotclock path ~/.config/nixos/home/modules/dot-clock-widget/noctalia-plugins
noctalia msg plugins enable vladyslav/dot-clock
```

Then add "Dot Clock" in the desktop or lock screen widget editor. `noctalia/config.toml`
already places one on the laptop desktop and one on each lock screen.

## Notes

- After editing the Luau files or `glyphs.txt`, reload the plugin:
  `noctalia msg plugins disable vladyslav/dot-clock && noctalia msg plugins enable vladyslav/dot-clock`.
- `ui.box` ignores `fillOpacity`; empty cells use the fully transparent fill `#00000000`.
- Changing a built-in clock widget into this plugin under the same widget id fails: Noctalia
  merges the old clock settings (`format`, `font_family`) and rejects them. Use a new widget id.
