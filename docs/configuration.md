# Configuration

## Keyboard layout
Not set by this repo. In `~/.config/hypr/hyprland.lua`: `hl.config({ input = { kb_layout = "us" } })`.

## Weather
- Dashboard (Media tab): create `~/.config/hyde-qs/location.json`
  ```json
  {"city": "Madrid", "lat": 40.4168, "lon": -3.7038}
  ```
  Without it the weather card is hidden. Data from Open-Meteo, no key needed.
- Lock screen: put `City,Country` in `~/.config/hyde/weather-location` (or set `HYDE_QS_WEATHER_LOCATION`).

## Google Calendar (optional)
```bash
./install.sh --with-calendar
```
Creates a Python venv, installs the sync/reminder timers and opens nothing without credentials. Create your own OAuth client following `~/.local/share/hyde-calendar/GOOGLE_SETUP.html`, then import it from the dashboard's settings. Credentials stay in `~/.config/hyde-calendar/` and are never part of this repo. The timezone is the system one.

## Claude Code sounds
Hooks in `~/.claude/hooks/` play `~/Music/claude-sounds/agudo.*` (needs you) and `grave.*` (task finished, turns of 15 s or more). Replace those files with your own mp3/ogg/wav. Do Not Disturb in the notification center mutes them.

## Keybindings
Defined in `config/hypr/hyde-qs.lua`:

| Keys | Action |
|---|---|
| `Super+N` / `Super+Shift+N` | notification center / Do Not Disturb |
| `Print` / `Super+Shift+S` | full screenshot / window or zone picker |
| `Super+L` | lock and suspend |
| `Alt+Enter` | normal, maximized, fullscreen |
| volume, brightness, Caps Lock | SwayOSD |

Waybar: click the clock for the dashboard, the music widget for the Media tab, the right-most button for the power menu.

## Edit and re-apply
Edit files in the repo and run `./install.sh`; commit what you like.
