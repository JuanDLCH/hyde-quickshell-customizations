# hyde-quickshell-customizations

My desktop on top of [HyDE](https://github.com/HyDE-Project/HyDE) (Hyprland on Arch Linux), packaged so that a fresh Arch + HyDE install becomes the same desktop with **one script**.

![waybar](docs/img/waybar.png)

| | |
|---|---|
| ![dashboard](docs/img/dashboard-home.png) | ![notifications](docs/img/notification-center.png) |
| **Dashboard**: clock, agenda, weather, mini player, calendar and a cat | **Notification center**: quick toggles, volume/brightness, player, grouped history, DND |

![power menu](docs/img/powermenu.png)

## What is included

- **Waybar "Unified" layout**: identity + workspaces, CPU/RAM, now-playing with album art and controls, clock that opens the dashboard, tray, audio/battery, tools and a power button.
- **Dashboard** (Quickshell): Home, Calendar (Google Calendar, optional), Media (player + weather), System (CPU, memory, disk, battery, uptime) and Focus (pomodoro + notes).
- **Notification center and popups** (Quickshell): replaces dunst/swaync, with Do Not Disturb and a Claude Code themed card.
- **Power menu** (Quickshell, wlogout fallback) and **screenshot picker** (`Print`, `Super+Shift+S`).
- **OSD** with SwayOSD for volume, brightness, Caps Lock and mic.
- **Hyprland additions** (Lua), hypridle, hyprsunset night light, Catppuccin Mocha theme files.
- **Claude Code hooks**: desktop notification and sound when Claude needs you or finishes a long task.

Details and more screenshots: [docs/components.md](docs/components.md).

## Install

```bash
# 1. Arch Linux + HyDE installed, logged into a Hyprland session
git clone https://github.com/JuanDLCH/hyde-quickshell-customizations
cd hyde-quickshell-customizations
./install.sh            # asks before installing missing packages
```

Options: `--yes` (no questions), `--dry-run`, `--no-claude`, `--with-calendar`, `--no-reload`.
Everything it replaces is backed up in `~/.local/state/hyde-qs/`, and `./uninstall.sh` restores it.
Full guide: [docs/install.md](docs/install.md).

## Configure

Keyboard layout, weather location, Google Calendar, sounds: see [docs/configuration.md](docs/configuration.md).
Problems? [docs/troubleshooting.md](docs/troubleshooting.md).

## Not included on purpose

Wallpapers, laptop-specific hardware keys (touchpad, camera, power profile, lid handling), patched binaries and any credentials. See [SECURITY.md](SECURITY.md).

## Credits

[HyDE](https://github.com/HyDE-Project/HyDE), [Quickshell](https://quickshell.org), [Catppuccin](https://github.com/catppuccin), [Lucide](https://lucide.dev) icons (license in `config/waybar/assets/lucide/`). MIT licensed.
