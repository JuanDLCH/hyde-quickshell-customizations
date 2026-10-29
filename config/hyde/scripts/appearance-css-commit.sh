#!/usr/bin/env bash
# One valid whitespace byte wakes Waybar's existing style monitor after commit.
# Imported files are complete; no signal, config rebuild, or process restart.
set -eu
style="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style.css"
[[ -f "$style" ]] || exit 0
printf '\n' >> "$style"
