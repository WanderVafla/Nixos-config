# NixOS Configuration

## 📁 Flake Structure

```
~/.config/nixos/
├── flake.nix                  # Entry point (Flake)
├── flake.lock                 # Dependency lock file
├── configuration.nix          # NixOS system configuration
├── hardware-configuration.nix # Auto-generated hardware config
└── home/
    ├── home.nix               # Home-manager (user packages)
    └── modules/
        ├── default.nix        # Module importer
        ├── hypr.nix           # Hyprland (Wayland compositor)
        ├── hypr/
        │   ├── hyprland.lua   # Hyprland config (Lua)
        │   └── noctalia.lua   # Noctalia theme for Hyprland
        ├── waybar.nix         # Waybar (status bar)
        ├── waybar/
        │   ├── config.jsonc
        │   └── style.css
        ├── kitty.nix          # Kitty (terminal)
        ├── nocatalia.nix      # Noctalia (shell/DE)
        ├── noctalia/
        │   └── config.toml
        ├── ashell.nix         # AShell (alternative shell) [disabled]
        ├── ashell/
        │   └── config.toml
        ├── zen-browser.nix    # Zen Browser [disabled]
        └── Wallpapers/        # Wallpaper collection
```

## 🔧 Essential Commands

### Apply changes after editing
```bash
# System-level changes (requires sudo)
sudo nixos-rebuild switch --flake ~/.config/nixos/

# User-level changes (home-manager)
home-manager switch --flake ~/.config/nixos/

# Hotkeys (defined in Hyprland):
# Super+Shift+U → nixos-rebuild switch
# Super+Shift+H → home-manager switch
# Super+Shift+N → open config folder in Zed
```

### Utility
```bash
# Open config in editor
zeditor ~/.config/nixos

# Check flake validity
nix flake check

# Update all flake inputs
nix flake update

# View rebuild history
nix profile history

# Check installed package versions
nix-env -q

# Diff two system generations
nix store diff-closures /nix/var/nix/profiles/system-*-link
```

## 🔄 Flake Inputs

| Input | Source | Purpose |
|---|---|---|
| `nixpkgs` | `nixos/nixpkgs` (nixos-unstable) | Main package repository |
| `home-manager` | `nix-community/home-manager` | User-level package management |
| `zen-browser` | `youwen5/zen-browser-flake` | Zen Browser |
| `noctalia` | `noctalia-dev/noctalia` | Shell/desktop environment |
| `noctalia-greeter` | `noctalia-dev/noctalia-greeter` | Login screen (greeter) |

## 💻 System Overview (configuration.nix)

- **Hostname:** `vladyslav`
- **User:** `vladyslav` (Vladyslav Chuhunov), in groups: `networkmanager`, `wheel`
- **Timezone:** `Europe/Zurich`
- **Locale:** `en_US.UTF-8`
- **Keyboard layout:** US
- **Bootloader:** systemd-boot, EFI
- **Kernel:** latest (`linuxPackages_latest`)
- **CPU:** AMD (kernel module `kvm-amd` enabled)
- **Networking:** NetworkManager + Tailscale (firewall trusts `tailscale0`)
- **Bluetooth:** enabled
- **Display server:** Hyprland (Wayland)
- **Display manager:** SDDM (disabled), using Noctalia Greeter instead
- **State version:** `26.05`

### Enabled services
- `upower` — power management
- `power-profiles-daemon` — power profiles
- `gvfs` — virtual filesystem (for trash, mounts, etc.)
- `polkit` — authorization
- `tailscale` — VPN/mesh networking

### System packages
htop, btop, sddm-chili-theme, home-manager, usb

## 👤 Home-manager Packages (home/home.nix)

| Package | Purpose |
|---|---|
| `zen-browser` | Zen web browser |
| `dolphin` | KDE file manager |
| `ark` | KDE archive utility |
| `p7zip` | 7-Zip CLI |
| `zed-editor` | Zed code editor |
| `nixd` / `nil` | Nix LSP servers |
| `direnv` + `nix-direnv` | Environment auto-loading |
| `git` | Version control |
| `micro` | Terminal text editor |
| `obsidian` | Note-taking |
| `opencode` | AI coding agent |
| `kitty` | GPU-accelerated terminal |
| `brightnessctl` | Brightness control (from nocatalia.nix) |

## 🪟 Hyprland (Lua Config)

- **Terminal:** kitty
- **File manager:** dolphin
- **App launcher:** Noctalia (via `vicinae toggle`)
- **Browser:** zen
- **Theme:** Noctalia (auto-generated, applied via Lua `require("noctalia")`)

### Keybindings

| Shortcut | Action |
|---|---|
| `Super + Q` | Open terminal |
| `Super + C` | Close window |
| `Super + E` | Open file manager |
| `Super + B` | Open browser |
| `Super + R` | Noctalia launcher |
| `Super + V` | Toggle window float |
| `Super + P` | Toggle pseudo-tiling |
| `Super + J` | Toggle split layout |
| `Super + L` | Lock and suspend |
| `Super + Shift + V` | Clipboard |
| `Super + Tab` | Control center |
| `Super + ,` | Settings |
| `Alt + Tab` | Window switcher |
| `Super + [0-9]` | Switch workspace |
| `Super + Shift + [0-9]` | Move window to workspace |
| `Super + S` | Toggle scratchpad (special workspace) |
| `Super + arrows` | Move focus |

### Media keys (all mapped through Noctalia IPC)
Volume up/down/mute, brightness up/down, play/pause/next/prev

### Keyboard layouts
- US and RU (Switch: `Alt + Shift`)
- Touchpad natural scroll: off
- 3-finger swipe: workspace switch

### Visual settings
- **Gaps:** 5px inner, 10px outer
- **Rounding:** 10px (power 2)
- **Border colors:** active gradient `#33ccff → #00ff99`, inactive `#595959`
- **Blur:** enabled, size 3, passes 2, vibrancy 0.1696
- **Shadow:** enabled, range 4, render power 3
- **Animations:** custom bezier curves + spring physics
- **Layout:** dwindle (with preserve_split)

## 🎨 Noctalia Shell

Noctalia is the primary desktop shell — it provides the bar, launcher, notifications, control center, lock screen, and wallpaper management.

### Bar
- Position: top, 34px thick
- Left section: launcher, keyboard layout, notifications, workspaces, active window
- Center: date, clock
- Right section: sysmon, clipboard, network, bluetooth, volume, brightness, battery, control center, session
- Auto-hide: off
- Radius: 12px (all corners)
- Shadow: on

### Control Center
- Width: 700px
- Sidebar: full (compact section)
- Shortcuts: wifi, bluetooth, caffeine, nightlight, notifications, power profile

### Lock Screen
- Enabled, with fingerprint
- Blur intensity: 0.5
- Two login boxes configured (for eDP-1 and HDMI-A-1)

### Notifications
- Position: top-right
- Background opacity: 0.97
- Daemon enabled, borders on, actions visible

### Wallpaper
- Directory: `/home/vladyslav/Downloads`
- Fill mode: crop
- Transitions: fade, wipe, disc, stripes, zoom, honeycomb
- Duration: 1500ms
- Automation: disabled (manual switching only)

### Theme
- Built-in: Noctalia (dark mode)
- Community palette: GitHub Dark
- Source: Wallpaper (M3 color extraction, `m3-content` scheme)
- Pure black: off
- Template targets: hyprland, kitty, zen-browser, obsidian, zed, vicinae, opencode

### System Monitor
- CPU: poll every 2s, warning at 50%, critical at 90%
- RAM: warning at 60%, critical at 90%
- GPU: poll disabled by default (set to 0)
- Temperature: warning at 60°C, critical at 85°C
- Network: poll every 3s

### Plugins
- Auto-update: on
- Enabled: `avivbintangaringga/nix-monitor`
- Sources: official-plugins, community-plugins (both from GitHub)

## 📐 How to Modify

### Add a system-level package
Edit `configuration.nix` → add to `environment.systemPackages`

### Add a user-level package
Edit `home/home.nix` → add to `home.packages`

### Add a new module
1. Create a `.nix` file in `home/modules/`
2. Add it to the `imports` list in `home/modules/default.nix`

### Change Hyprland behavior
Edit `home/modules/hypr/hyprland.lua` (Lua-based Hyprland config)

### Change theme colors
Edit `home/modules/hypr/noctalia.lua` or let Noctalia regenerate it via wallpaper change

### Change Noctalia settings
Edit `home/modules/noctalia/config.toml`

### Toggle a module on/off
Comment/uncomment its import in `home/modules/default.nix`

## ⚙️ Dev Tools for Config Editing

- **Editor:** Zed (`zeditor ~/.config/nixos`)
- **LSP for Nix:** nixd / nil (both installed)
- **Formatter:** nixpkgs-fmt (not explicitly in packages, but available via nixpkgs)
- **Validation:** `nix flake check`
- **Direnv:** available if projects have `.envrc`

## 📌 Notes & Caveats

- `zen-browser` is installed both as a flake input package in `home.nix` AND has a separate module file `zen-browser.nix` (which is commented out in `default.nix`) — the module's only function is to import zen's home-manager module for userChrome/userContent CSS theming
- `ashell.nix` is not imported in `default.nix` — it's a disabled alternative to Noctalia
- `noctalia.lua` is a symlink from the Noctalia cache, made writable via `home.activation` block so Noctalia can update it
- `hardware-configuration.nix` is **auto-generated** — do not edit manually; run `nixos-generate-config` to regenerate
- `stateVersion = "26.05"` — bump carefully only when upgrading NixOS; it affects stateful data paths
- Noctalia config and theme files are made writable after home-manager activation so the Noctalia app can modify them at runtime
- The wallpaper `transition_on_startup` is off — no slide transition on login
