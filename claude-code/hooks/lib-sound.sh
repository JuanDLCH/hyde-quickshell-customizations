#!/bin/sh
# Shared helpers for the Claude Code hooks. play_sound <agudo|grave>: respects the notification center's Do Not Disturb.
play_sound() {
    [ "$(cat "$HOME/.local/state/hyde-notifications/dnd" 2>/dev/null)" = 1 ] && return 0
    f=$(ls "$HOME/Music/claude-sounds/$1".* 2>/dev/null | head -1)
    [ -n "$f" ] || f=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga
    setsid pw-play "$f" >/dev/null 2>&1 &
}
project() {
    p=$(basename "${1:-~}"); [ "$p" = "$(basename "$HOME")" ] && p="~"; printf '%s' "$p"
}
