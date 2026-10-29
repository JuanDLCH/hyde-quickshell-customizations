#!/bin/sh
# UserPromptSubmit hook: remember when this turn started, so Stop can tell short answers from real work.
in=$(cat)
sid=$(printf '%s' "$in" | jq -r '.session_id // "x"')
date +%s > "${XDG_RUNTIME_DIR:-/tmp}/claude-turn-$sid"
