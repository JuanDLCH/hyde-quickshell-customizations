#!/usr/bin/env bash
# User override: keep upstream rendering/authentication, remove PAM-backed previews.
set -e
lib=${LIB_DIR:-$HOME/.local/lib}
upstream="$lib/hyde/hyprlock.sh"
helper="${XDG_CONFIG_HOME:-$HOME/.config}/hyde/scripts/hyprlock-safe.py"
mode=${1:-}
for arg in "$@"; do
    case "$arg" in
        --test|--test-preview|--test=*|--test-preview=*)
            printf 'PAM-backed previews are disabled; select a layout without locking.\n' >&2
            exit 2 ;;
        --select|-S) mode=--select ;;
        --reload|-r) mode=--reload ;;
    esac
done
case $mode in
    --select|-S)
        export LIB_DIR="$lib"
        source "$lib/hyde/globalcontrol.sh"
        source "$lib/hyde/shutils/argparse.sh"
        argparse_init "$@"
        argparse_program 'hyde-shell hyprlock'
        argparse "--select,-S" "" "Select a layout without locking or authenticating"
        argparse_finalize
        export HYPRLOCK_LAYOUT ROFI_HYPRLOCK_STYLE
        exec python3 "$helper" --select
        ;;
    --test|--test-preview)
        printf 'Automatic Hyprlock previews are disabled: they start a real PAM conversation. Select a layout, then coordinate a normal lock test.\n' >&2
        exit 2
        ;;
    '') exec python3 "$helper" --launch "$upstream" ;;
    --reload|-r) exec python3 "$helper" --edit "$upstream" "$@" ;;
    background|--background|-b|profile|--profile|mpris|--mpris|cava|art|--art|--help|-h)
        exec "$upstream" "$@" ;;
    *) exec python3 "$helper" --launch "$upstream" "$@" ;;
esac
