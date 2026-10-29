#!/bin/sh
# Stop hook. Short answers stay quiet; a turn that ran 15 s or more gets "Task finished" + the finish sound.
. "$(dirname "$0")/lib-sound.sh"
in=$(cat)
sid=$(printf '%s' "$in" | jq -r '.session_id // "x"')
proj=$(project "$(printf '%s' "$in" | jq -r '.cwd // ""')")
f="${XDG_RUNTIME_DIR:-/tmp}/claude-turn-$sid"
start=$(cat "$f" 2>/dev/null); rm -f "$f"
[ -n "$start" ] && [ $(( $(date +%s) - start )) -ge 15 ] || exit 0
notify-send -a claude-code "Claude Code · $proj" "Task finished"
play_sound grave
