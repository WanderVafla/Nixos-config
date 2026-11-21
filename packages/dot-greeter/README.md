# dot-greeter

Minimal console greeter for greetd. It shows no border and no username: a blinking grey `│`
cursor with a dim `password` placeholder while nothing is typed, one white `•` per typed
character, and red dots for a wrong password. While PAM checks an answer, the dots turn dim and
a light runs over them. After several wrong passwords in a row the placeholder turns into a
hint (`check caps lock`). While the fingerprint reader waits, a dot pulses next to
`touch the sensor` and turns red for a second after a scan that does not match. A password
entered with Enter during that wait is sent as soon as PAM asks for it. The line is always
centered.

The console font is the system monospace font (`fonts.fontconfig.defaultFonts.monospace`),
converted to a 16x32 PSF by `packages/console-font` (missing glyphs come from Terminus).
`module.nix` provides `services.dot-greeter`; `system/greeter.nix` turns it on.

| File | Responsibility |
|---|---|
| `src/main.rs` | Entry point: parses the arguments and starts the loop |
| `src/args.rs` | Command line: `--user NAME [OPTIONS] -- CMD [ARGS]...` (see `dot-greeter --help` text in `USAGE`) |
| `src/style.rs` | Characters, colors, placeholder, hint and blink speed, with defaults |
| `src/app.rs` | Event loop: keys, greetd responses, redraws, restart timers |
| `src/session.rs` | The greetd conversation as a pure state machine (unit tested) |
| `src/worker.rs` | Thread that owns the greetd socket, so the screen never blocks on PAM |
| `src/input.rs` | Typed text in a zeroizing buffer; Enter, Backspace, Esc and Ctrl+U |
| `src/screen.rs` | One centered line on the console; restores the terminal on exit or panic |
| `package.nix` | `buildRustPackage`, runs the unit tests |
| `module.nix` | NixOS options, greetd setup, console font and the glyph check |

## NixOS options

| Option | Default | Meaning |
|---|---|---|
| `enable` | `false` | Use dot-greeter as the greetd greeter |
| `user` | — | The only user who logs in |
| `command` | `[ start-hyprland ]` | Session started after login |
| `environment` | Hyprland `XDG_*` variables | Environment of the session |
| `placeholder` | `"password"` | Dim text while nothing is typed |
| `dot` | `"•"` | Character per typed letter |
| `cursor` | `"│"` | Blinking cursor; `null` hides it |
| `blinkMs` | `530` | Cursor on time and off time, in ms |
| `wrongPasswordHint.attempts` | `3` | Wrong passwords in a row before the hint; `0` turns it off |
| `wrongPasswordHint.text` | `"check caps lock"` | Text that replaces the placeholder |
| `fingerprint.text` | `"touch the sensor"` | Text next to the pulsing dot while the reader waits |
| `fingerprint.timeout` | `10` | Seconds pam_fprintd waits before the password is accepted; `null` keeps 30 |
| `colors.{typed,cursor,placeholder,wrong,checking,hint,fingerprint}` | white, grey, dark-grey, red, dark-grey, dark-red, white | One of the 16 console colors |
| `quietBoot` | `true` | Kernel `quiet` and `udev.log_level=3`: no boot text before the greeter |
| `font.enable` | `true` | Set the console font (greeter and Ctrl+Alt+F2) |
| `font.family` | first of `fonts.fontconfig.defaultFonts.monospace` | Monospaced family from `fonts.packages` |

The console holds only 512 glyphs, so `dot`, `cursor`, `placeholder` and the hint text are
checked against the console font at build time: a missing character fails the build with its
name instead of showing a blank box on the login screen.

## How it works

- greetd protocol: `CreateSession` → `AuthMessage` (secret, visible, info, error) →
  `PostAuthMessageResponse` → `Success` → `StartSession`. PAM in greetd does the checking
  (password, fingerprint, gnome-keyring); the greeter only relays the answers.
- Info messages (such as "place your finger") get an empty reply right away, and the screen
  keeps the dim dot.
- A wrong password (`AuthError`) shows red dots for 1 s. Other errors show a dim `!` for 2 s.
  Both then cancel the session and start over.
- The greeter never exits on errors: when the greeter exits without a session, greetd stops,
  and `greetd.service` is not restarted. A lost socket is reconnected every 2 s.
- Ctrl+C and other Ctrl shortcuts are ignored. The password is never printed or logged, and its
  buffer is wiped after it is sent.

## Testing

```bash
cd packages/dot-greeter
nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc -c cargo test
# fakegreet ships with greetd and fakes the protocol: user "user", password "password", then "7 + 2:" → 9.
# Run it from a short path: the socket path must fit in sockaddr_un.
cd /tmp/fg && fakegreet "$(nix build --print-out-paths ...)/bin/dot-greeter --user user -- true"
```

To test the whole login, build a VM with `system/greeter.nix` added through `extendModules`
and `virtualisation.vmVariant.users.users.vladyslav.initialPassword` set, so `configuration.nix`
does not have to change.

## Known limitations

- While pam_fprintd waits for the finger, PAM accepts no password until the scan times out or
  fails 3 times.
- A fingerprint login does not unlock gnome-keyring. Only a password login does.
- The password is typed in the console keymap (US).
