#!/usr/bin/env bash
# Build swayosd-server with swayosd/compact-osd.patch for the SwayOSD version installed here,
# and install it to ~/.local/libexec/hyde-qs/. bin/hyde-qs-swayosd runs it only while
# /usr/bin/swayosd-server is still the build it was made against; after a SwayOSD update it
# falls back to the stock server until you run this again.
#   scripts/build-swayosd.sh [--dry-run]
# Needs: cargo (Arch: rust), curl, patch, and SwayOSD's build deps (installed with swayosd).
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PATCH="$SRC/swayosd/compact-osd.patch"
DEST="$HOME/.local/libexec/hyde-qs"
WORK="${XDG_CACHE_HOME:-$HOME/.cache}/hyde-qs/swayosd-build"
DRY=0; [[ ${1:-} == --dry-run ]] && DRY=1

command -v swayosd-server >/dev/null || { echo "swayosd is not installed" >&2; exit 1; }
command -v cargo >/dev/null || { echo "cargo not found: install rust (sudo pacman -S --needed rust)" >&2; exit 1; }
stock=$(command -v swayosd-server)
[[ $stock != "$DEST/"* ]] || stock=/usr/bin/swayosd-server
ver=$(pacman -Q swayosd 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//')
[[ -n $ver ]] || ver=$("$stock" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
[[ -n $ver ]] || { echo "cannot tell the installed SwayOSD version" >&2; exit 1; }
echo "SwayOSD $ver ($stock)"

rm -rf "$WORK"; mkdir -p "$WORK"
curl -fsSL "https://github.com/ErikReider/SwayOSD/archive/refs/tags/v$ver.tar.gz" | tar xz -C "$WORK"
cd "$WORK/SwayOSD-$ver"
if ! patch -p1 --dry-run --quiet <"$PATCH" >/dev/null; then
    echo "The patch does not apply to SwayOSD $ver; keeping the stock server. Update swayosd/compact-osd.patch." >&2
    exit 1
fi
patch -p1 --quiet <"$PATCH"
((DRY)) && { echo "[dry-run] patch applies to $ver; not building"; exit 0; }
cargo build --release --locked --bin swayosd-server
install -Dm755 target/release/swayosd-server "$DEST/swayosd-server"
sha256sum "$stock" | awk '{print $1}' >"$DEST/swayosd-server.base-sha256"
echo "Installed $DEST/swayosd-server (for stock build $(cut -c1-12 "$DEST/swayosd-server.base-sha256")…)."
echo "Restart it: pkill -x swayosd-server; setsid -f hyde-qs-swayosd --top-margin 0.84"
