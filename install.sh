#!/usr/bin/env bash
# hyde-quickshell-customizations installer.
# Run it after a fresh Arch + HyDE install:  ./install.sh
#
#   --yes            do not ask questions (installs missing packages)
#   --dry-run        print what would happen, change nothing
#   --no-claude      skip the Claude Code hooks and sounds
#   --with-calendar  also set up the Google Calendar backend (venv + systemd timers)
#   --no-reload      do not reload Hyprland / restart waybar and Quickshell
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hyde-qs"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$STATE/backup-$STAMP"
MANIFEST="$STATE/manifest"
MARK_BEGIN='-- >>> hyde-quickshell-customizations >>>'
MARK_END='-- <<< hyde-quickshell-customizations <<<'

YES=0 DRY=0 CLAUDE=1 CALENDAR=0 RELOAD=1
for a in "$@"; do
    case $a in
        --yes|-y) YES=1 ;;
        --dry-run) DRY=1 ;;
        --no-claude) CLAUDE=0 ;;
        --with-calendar) CALENDAR=1 ;;
        --no-reload) RELOAD=0 ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

say()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if ((DRY)); then echo "   [dry-run] $*"; else "$@"; fi; }

# ---- preflight --------------------------------------------------------------
[[ -r /etc/arch-release ]] || warn "This is not Arch Linux; continuing, but only Arch + HyDE is tested."
[[ -d $HOME/.config/hyde || -x $(command -v hyde-shell 2>/dev/null || true) ]] \
    || die "HyDE not found. Install HyDE first: https://github.com/HyDE-Project/HyDE"
[[ -n ${WAYLAND_DISPLAY:-}${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || warn "Not inside a Hyprland session: the final reload step will be skipped."

# ---- dependencies -----------------------------------------------------------
say "Checking dependencies"
DEP_ARGS=()
((YES)) && DEP_ARGS+=(--yes)
((DRY)) && DEP_ARGS+=(--dry-run)
((CALENDAR)) && DEP_ARGS+=(--calendar)
"$SRC/scripts/check-deps.sh" "${DEP_ARGS[@]}"

# ---- copy helpers -----------------------------------------------------------
((DRY)) || mkdir -p "$STATE"
record() { ((DRY)) || printf '%s\n' "$1" >> "$MANIFEST"; }

# install_file <repo file> <destination>: backup, render @HOME@, keep mode
install_file() {
    local src=$1 dst=$2 tmp
    if [[ -e $dst || -L $dst ]]; then
        if ! cmp -s <(sed "s#@HOME@#$HOME#g" "$src" 2>/dev/null || cat "$src") "$dst"; then
            if ! ((DRY)); then
                mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
                cp -a "$dst" "$BACKUP/${dst#"$HOME"/}"
            fi
            echo "   backup  ${dst/#$HOME/~}"
        else
            return 0
        fi
    else
        record "$dst"
    fi
    echo "   install ${dst/#$HOME/~}"
    ((DRY)) && return 0
    mkdir -p "$(dirname "$dst")"
    if grep -Iq . "$src" 2>/dev/null; then
        tmp=$(mktemp); sed "s#@HOME@#$HOME#g" "$src" > "$tmp"
        install -m "$(stat -c %a "$src")" "$tmp" "$dst"; rm -f "$tmp"
    else
        install -m "$(stat -c %a "$src")" "$src" "$dst"
    fi
}

# install_tree <repo dir> <destination dir>
install_tree() {
    local srcdir=$1 dstdir=$2 f
    while IFS= read -r -d '' f; do
        install_file "$f" "$dstdir/${f#"$srcdir"/}"
    done < <(find "$srcdir" -type f -print0 | sort -z)
}

# ---- core -------------------------------------------------------------------
say "Installing helpers (~/.local/bin)"
install_tree "$SRC/bin" "$HOME/.local/bin"

say "Installing Quickshell components (notifications, dashboard, power menu, screenshot)"
install_tree "$SRC/config/quickshell" "$HOME/.config/quickshell"

say "Installing waybar layout and styles"
install_tree "$SRC/config/waybar" "$HOME/.config/waybar"
install_file "$SRC/config/waybar/layouts/Unified.jsonc" "$HOME/.config/waybar/config.jsonc"

say "Installing OSD, wlogout and HyDE scripts"
install_tree "$SRC/config/swayosd" "$HOME/.config/swayosd"
install_tree "$SRC/config/wlogout" "$HOME/.config/wlogout"
install_tree "$SRC/config/hyde/scripts" "$HOME/.config/hyde/scripts"
[[ -e $HOME/.config/hyde/config.toml ]] \
    && warn "~/.config/hyde/config.toml exists: merge config/hyde/config.toml by hand (see docs/configuration.md)" \
    || install_file "$SRC/config/hyde/config.toml" "$HOME/.config/hyde/config.toml"

say "Installing theme tweaks (Catppuccin Mocha, no wallpapers)"
for t in "$SRC"/themes/*/; do
    name=$(basename "$t")
    if [[ -d $HOME/.config/hyde/themes/$name ]]; then
        install_tree "${t%/}" "$HOME/.config/hyde/themes/$name"
    else
        warn "Theme '$name' is not installed in HyDE; skipping (install it from the HyDE theme list first)"
    fi
done

say "Installing Hyprland additions"
install_file "$SRC/config/hypr/hyde-qs.lua" "$HOME/.config/hypr/hyde-qs.lua"
install_file "$SRC/config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
install_file "$SRC/config/hypr/hyprsunset.conf" "$HOME/.config/hypr/hyprsunset.conf"
HLUA="$HOME/.config/hypr/hyprland.lua"
if [[ -f $HLUA ]] && ! grep -qF -- "$MARK_BEGIN" "$HLUA"; then
    echo "   append  require(\"hyde-qs\") to ~/.config/hypr/hyprland.lua"
    if ! ((DRY)); then
        mkdir -p "$BACKUP/.config/hypr"; cp -a "$HLUA" "$BACKUP/.config/hypr/hyprland.lua"
        printf '\n%s\nrequire("hyde-qs")\n%s\n' "$MARK_BEGIN" "$MARK_END" >> "$HLUA"
    fi
elif [[ ! -f $HLUA ]]; then
    warn "No ~/.config/hypr/hyprland.lua (older HyDE?). Add the binds from config/hypr/hyde-qs.lua to your Hyprland config by hand."
fi

# ---- Claude Code ------------------------------------------------------------
if ((CLAUDE)); then
    say "Installing Claude Code hooks and notification sounds"
    install_tree "$SRC/claude-code/hooks" "$HOME/.claude/hooks"
    install_tree "$SRC/claude-code/sounds" "$HOME/Music/claude-sounds"
    SETTINGS="$HOME/.claude/settings.json"
    if command -v jq >/dev/null; then
        echo "   merge   hooks into ~/.claude/settings.json"
        if ! ((DRY)); then
            mkdir -p "$HOME/.claude"; [[ -f $SETTINGS ]] || echo '{}' > "$SETTINGS"
            mkdir -p "$BACKUP/.claude"; cp -a "$SETTINGS" "$BACKUP/.claude/settings.json"
            jq -s '.[0] as $cur | .[1] as $new
                | $cur | .hooks = (reduce ($new.hooks | keys[]) as $ev (($cur.hooks // {});
                    .[$ev] = ((.[$ev] // []) as $old | $old + [($new.hooks[$ev][] | select(. as $h | ($old | map(tojson) | index($h | tojson)) | not))])))' \
                "$SETTINGS" "$SRC/claude-code/settings.hooks.json" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        fi
    else
        warn "jq missing: merge claude-code/settings.hooks.json into ~/.claude/settings.json by hand"
    fi
fi

# ---- Google Calendar --------------------------------------------------------
if ((CALENDAR)); then
    say "Setting up the Google Calendar backend"
    CAL="$HOME/.local/share/hyde-calendar"
    install_tree "$SRC/calendar/app" "$CAL/app"
    install_file "$SRC/calendar/GOOGLE_SETUP.html" "$CAL/GOOGLE_SETUP.html"
    if [[ ! -x $CAL/venv/bin/python ]]; then
        run python -m venv "$CAL/venv"
        run "$CAL/venv/bin/pip" install --quiet google-auth google-auth-oauthlib
    fi
    install_tree "$SRC/systemd" "$HOME/.config/systemd/user"
    run systemctl --user daemon-reload
    run systemctl --user enable --now hyde-calendar-sync.timer hyde-calendar-remind.timer
    warn "Calendar needs your own Google OAuth client: open $CAL/GOOGLE_SETUP.html"
fi

# ---- reload -----------------------------------------------------------------
if ((RELOAD && !DRY)) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    say "Reloading"
    hyprctl reload >/dev/null 2>&1 || true
    pkill -SIGUSR2 waybar 2>/dev/null || true
    for c in notifications calendar screenshot powermenu; do
        pkill -f "quickshell -c $c" 2>/dev/null || true
        setsid -f quickshell -c "$c" >/dev/null 2>&1 || true
    done
fi

((DRY)) && say "Dry run finished, nothing was changed." || say "Done. Backups: ${BACKUP/#$HOME/~}  (undo with ./uninstall.sh)"
