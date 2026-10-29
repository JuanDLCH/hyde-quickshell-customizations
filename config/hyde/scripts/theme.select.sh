#!/usr/bin/env bash
# Serialize complete appearance operations, including selectors launched from Waybar.
# flock --close keeps unrelated module hooks from retaining the lock descriptor.
set -eu
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyde"
mkdir -p "$runtime"
export HYDE_SHELL_INIT=0
export HYDE_APPEARANCE_CSS_COMMIT="${HOME}/.config/hyde/scripts/appearance-css-commit.sh"
exec flock --close --wait 45 "$runtime/appearance.lock" bash "${HOME}/.local/lib/hyde/theme.select.sh" "$@"
