#!/bin/sh
# Notification hook. Sound only when Claude is actually blocked on you (permission / question dialog).
# idle_prompt ("waiting for your input", ~60 s after a turn ends) is dropped: Stop already announced it.
. "$(dirname "$0")/lib-sound.sh"
in=$(cat)
type=$(printf '%s' "$in" | jq -r '.notification_type // ""')
msg=$(printf '%s' "$in" | jq -r '.message // "Claude Code"')
proj=$(project "$(printf '%s' "$in" | jq -r '.cwd // ""')")
case $type in
    idle_prompt|auth_success) exit 0 ;;
esac
notify-send -a claude-code "Claude Code · $proj" "$msg"
play_sound agudo
