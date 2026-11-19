# dot-spectrum

Noctalia plugin `vladyslav/dot-spectrum`: an audio visualizer made of dots, after the music card
of the Nothing-style mockup.

- **Bar widget** `spectrum`: a 7x4 dot equalizer.
- **Desktop widget** `player`: the music card of the mockup. A disc of 9 dot rings around an
  accent center dot (each ring swells with its band and the pattern turns slowly while music
  plays), then the player, the title in Doto Round, artist and album, a 30-dot progress bar with
  the playhead in the accent color, and the times. Data from `noctalia.mediaPlayer()`.
  `transparent_background` drops the card's fill and outline.
- **Desktop widget** `matrix`: a round 25x25 dot matrix like the Glyph Matrix of the Nothing
  Phone (3). Ring k (from the center out) shows frequency band k, bass in the middle; the louder
  the band, the more of its dots light up, in a fixed scattered order. The center dot uses the
  accent color, unlit dots stay faintly visible.

| File | Responsibility |
|---|---|
| `noctalia-plugins/catalog.toml` | Catalog of this local plugin source |
| `dot-spectrum/plugin.toml` | Manifest: bar and desktop widgets and their settings |
| `dot-spectrum/bar.luau` | Receives the spectrum, draws the equalizer, relays frames (20 per second) |
| `dot-spectrum/synth.luau` | Made-up spectrum for music the laptop cannot hear |
| `dot-spectrum/matrix.luau` | Draws the round matrix from the relayed frames |
| `dot-spectrum/player.luau` | Music card: player data, text, progress dots |
| `dot-spectrum/disc.luau` | Dot rings placed with translateX/Y (rows in a column, each shifted back by the rows above) |
| `dot-spectrum/channel.luau` | Shared state key and band count |
| `dot-spectrum/translations/en.json` | Setting labels |

## Why two widgets

Noctalia delivers the audio spectrum (`onAudioSpectrum`) only to bar widgets, and only when the
bar widget's config has `audio_spectrum = true`. The desktop matrix therefore needs the bar
widget somewhere in a bar; it reads the frames from `noctalia.state`.

The spectrum comes from the output sink: with the output muted the matrix stays still.

## Music playing elsewhere

When a player reports `Playing` but the sink is silent (Spotify Connect to the phone, the
phone's own player mirrored as MPRIS `phone`), the bar widget relays a made-up spectrum from
`synth.luau` instead: slow waves per band and a soft beat on the bass. It does not follow the
real music. Real audio takes over within 400 ms. While nothing plays the widget only checks the
player once a second. Turn it off with `simulate_when_silent = false` on the bar widget.

## Setting up

```sh
noctalia msg plugins source add dotspectrum path ~/.config/nixos/home/modules/dot-spectrum/noctalia-plugins
noctalia msg plugins enable vladyslav/dot-spectrum
noctalia msg config-set widget.dot-spectrum '{ type = "vladyslav/dot-spectrum:spectrum", audio_spectrum = true, audio_spectrum_bands = 13 }'
```

Then put `dot-spectrum` in a bar and add the matrix or the player in the desktop widget editor.
`noctalia/config.toml` already does both. Set `background = false` on the desktop widget to drop
the card behind it.

After editing the Luau files: `noctalia msg plugins disable vladyslav/dot-spectrum && noctalia msg plugins enable vladyslav/dot-spectrum`.

The title font, Doto Round, carries the Cyrillic of `fonts/doto-glyphs.txt`; the card raises
Russian and Ukrainian titles to capitals itself, since `string.upper` only knows ASCII.
