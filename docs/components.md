# Components

## Waybar
Layout `config/waybar/layouts/Unified.jsonc` (installed as `config.jsonc`), styles in `styles/unified.css` and `user-style.css`, Lucide icons in `assets/`. Colors follow HyDE's wallbash theme.

![waybar](img/waybar.png)

## Dashboard
`config/quickshell/calendar`. Toggle: `quickshell ipc -c calendar call calendar toggle`; tabs: `... call calendar tab 0..4`.

| Home | Calendar |
|---|---|
| ![](img/dashboard-home.png) | ![](img/dashboard-calendar.png) |
| **Media** | **System** |
| ![](img/dashboard-media.png) | ![](img/dashboard-system.png) |

![focus](img/dashboard-focus.png)

## Notification center
`config/quickshell/notifications`, controlled by `notif {toggle|open|close|toggleDnd|clear}`. Also acts as the notification daemon.

![](img/notification-center.png)

## Power menu
`config/quickshell/powermenu`, toggled by `hyde-qs-powermenu` (falls back to wlogout).

![](img/powermenu.png)

## Screenshots
`config/quickshell/screenshot` + `bin/shot`. Files go to `~/Pictures/Screenshots` and the clipboard.

## Helpers
`bin/hyde-qs-media` (album art, seek, focus the player window), `bin/waybar-nowplaying`, `bin/notif`, `bin/shot`.
