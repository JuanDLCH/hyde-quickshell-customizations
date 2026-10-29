#!/usr/bin/env bash
# Undo install.sh: restore the files it backed up, delete the ones it created.
set -euo pipefail
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hyde-qs"
MARK_BEGIN='-- >>> hyde-quickshell-customizations >>>'
MARK_END='-- <<< hyde-quickshell-customizations <<<'

[[ -d $STATE ]] || { echo "Nothing to undo: no install state in $STATE" >&2; exit 1; }

# Oldest backup first so the original file wins when several installs touched it.
for b in $(ls -d "$STATE"/backup-* 2>/dev/null | sort -r); do
    echo ":: restoring $b"
    cp -a "$b"/. "$HOME"/
done
if [[ -f $STATE/manifest ]]; then
    while IFS= read -r f; do
        [[ -n $f && -e $f ]] && { echo "   remove ${f/#$HOME/~}"; rm -f "$f"; }
    done < "$STATE/manifest"
fi
HLUA="$HOME/.config/hypr/hyprland.lua"
[[ -f $HLUA ]] && sed -i "\#^$MARK_BEGIN#,\#^$MARK_END#d" "$HLUA"
rm -rf "$STATE"
echo ":: done. Reload with: hyprctl reload"
