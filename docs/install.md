# Install

## Requirements
- Arch Linux with [HyDE](https://github.com/HyDE-Project/HyDE) installed (it uses HyDE's Lua Hyprland config, `~/.config/hypr/hyprland.lua`).
- A running Hyprland session (the installer reloads it at the end).
- Packages (the installer offers to install them): `quickshell waybar swayosd playerctl grim slurp wl-clipboard jq libnotify pipewire imagemagick curl hyprland wlogout hyprsunset xdg-user-dirs python`.

## Steps
```bash
git clone https://github.com/JuanDLCH/hyde-quickshell-customizations
cd hyde-quickshell-customizations
./install.sh --dry-run   # optional: see what would change
./install.sh
```

## What it does
1. Checks dependencies (`scripts/check-deps.sh`).
2. Copies files, resolving the `@HOME@` placeholder to your home. Existing files that differ are backed up to `~/.local/state/hyde-qs/backup-<date>/`.
3. Adds `require("hyde-qs")` (between marker comments) to `~/.config/hypr/hyprland.lua` and merges the Claude Code hooks into `~/.claude/settings.json` without touching your own.
4. Reloads Hyprland, waybar and starts the Quickshell components.

Theme files are only applied to themes that already exist in HyDE (Catppuccin Mocha); select it from HyDE's theme picker. Wallpapers are not shipped.

## Uninstall
`./uninstall.sh` restores backups, deletes created files and removes the `require` line.

## Updating
`git pull && ./install.sh`. Unchanged files are skipped.
