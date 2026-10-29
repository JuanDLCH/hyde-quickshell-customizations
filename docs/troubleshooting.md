# Troubleshooting

- **Installer says HyDE not found**: install HyDE first.
- **Binds do nothing**: open `~/.config/hypr/hyprland.lua`; the `require("hyde-qs")` block must be there. Run `hyprctl reload` and check `hyprctl configerrors`.
- **No notifications**: only one daemon may own the D-Bus name. `pkill dunst; pkill swaync; quickshell -c notifications`.
- **Dashboard does not open**: `quickshell -c calendar` in a terminal shows QML errors.
- **No weather card**: create `~/.config/hyde-qs/location.json` (see configuration).
- **Calendar empty**: run with `--with-calendar` and import your own Google OAuth client.
- **No Claude Code sound**: check `pw-play ~/Music/claude-sounds/agudo.mp3` and that Do Not Disturb is off.
- **Undo everything**: `./uninstall.sh`.
