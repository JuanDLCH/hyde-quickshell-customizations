#!/usr/bin/env bash
# Verify (and optionally install) the packages the customizations rely on.
#   --yes       install missing packages without asking
#   --dry-run   only report
#   --calendar  also require the Python bits for the Google Calendar backend
set -euo pipefail
YES=0 DRY=0 CAL=0
for a in "$@"; do
    case $a in --yes) YES=1 ;; --dry-run) DRY=1 ;; --calendar) CAL=1 ;; esac
done

# command -> package
declare -A PKG=(
    [quickshell]=quickshell [waybar]=waybar [swayosd-client]=swayosd [playerctl]=playerctl
    [grim]=grim [slurp]=slurp [wl-copy]=wl-clipboard [jq]=jq [notify-send]=libnotify
    [pw-play]=pipewire [magick]=imagemagick [curl]=curl [hyprctl]=hyprland [wlogout]=wlogout
    [hyprsunset]=hyprsunset [xdg-user-dir]=xdg-user-dirs [python3]=python
)
((CAL)) && PKG[python-venv-check]=python
missing=()
for cmd in "${!PKG[@]}"; do
    [[ $cmd == python-venv-check ]] && continue
    command -v "$cmd" >/dev/null 2>&1 || missing+=("${PKG[$cmd]}")
done
mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u | sed '/^$/d')

if ((${#missing[@]} == 0)); then echo "   all dependencies present"; exit 0; fi
echo "   missing packages: ${missing[*]}"
((DRY)) && exit 0
helper=$(command -v yay || command -v paru || true)
if [[ -z $helper && ! -x /usr/bin/pacman ]]; then echo "   no pacman/yay found: install them yourself" >&2; exit 1; fi
if ((!YES)); then
    read -rp "   install them now? [Y/n] " ans
    [[ ${ans:-y} =~ ^[Yy] ]] || { echo "   skipped; some features may not work" >&2; exit 0; }
fi
if [[ -n $helper ]]; then "$helper" -S --needed --noconfirm "${missing[@]}"
else sudo pacman -S --needed --noconfirm "${missing[@]}"; fi
