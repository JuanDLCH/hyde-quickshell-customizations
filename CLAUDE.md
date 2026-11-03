# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The owner's desktop shell on top of HyDE (Hyprland, Lua config, Arch): Waybar "Unified", Quickshell
dashboard/notifications/power menu/screenshot picker, SwayOSD, theme files, Claude Code hooks.
`README.md` and `docs/` cover usage. Status: **on standby** while the owner tries Ryoku. It must
stay reinstallable on a fresh Arch + HyDE with `./install.sh`.

Companion repo: [JuanDLCH/dotfiles](https://github.com/JuanDLCH/dotfiles) (chezmoi) owns
everything that is not the desktop shell: keybinds, laptop Fn keys (`~/.local/libexec/hw-keys/hw`),
lid/idle policy, app suites and the personal weather location (`~/.config/hyde-qs/location.json`,
`~/.config/hyde/weather-location`). Restore order: HyDE, then `chezmoi init --apply JuanDLCH`
(desktop `hyprland-lua`), then `./install.sh`. Don't move hardware or personal data into this repo.

## How install works

- `install.sh` copies files (not symlinks) with `install_tree` / `install_file`. Each file is
  rendered with `@HOME@` → `$HOME`, any file it replaces is backed up to
  `~/.local/state/hyde-qs/backup-<stamp>/`, and created files go in a manifest. `uninstall.sh`
  restores the backups and deletes the manifest entries.
- `config/waybar/layouts/Unified.jsonc` is installed both as a layout and as `~/.config/waybar/config.jsonc`.
- Hyprland: `config/hypr/hyde-qs.lua` is loaded by a `require("hyde-qs")` block that the installer appends to
  `~/.config/hypr/hyprland.lua` between `-- >>> hyde-quickshell-customizations >>>` markers.
  Binds there must `hl.unbind` first to replace HyDE's.
- `config/hyde/config.toml` is only written when the user has none; otherwise it's a merge-by-hand snippet.
- Quickshell runs as separate always-on instances (`quickshell -c calendar|notifications|screenshot|powermenu`),
  driven over IPC (`quickshell ipc -c <name> call …`, wrapped by `bin/notif`, `bin/hyde-qs-powermenu`).
- SwayOSD: HyDE never starts `swayosd-server`, so `hyde-qs.lua` starts `bin/hyde-qs-swayosd`. That
  wrapper runs the compact build (`swayosd/compact-osd.patch`, built by `scripts/build-swayosd.sh`
  / `install.sh --with-osd-patch`) only while `/usr/bin/swayosd-server` matches the sha256 it was
  built against, else the stock server. Ship the patch as source, never a binary.

## Commands

```bash
./install.sh --dry-run --yes --no-reload        # what would change (add --with-osd-patch / --with-calendar)
bash scripts/secret-scan.sh                     # run before every commit; must print "clean"
scripts/check-deps.sh --dry-run                 # dependency report
scripts/build-swayosd.sh --dry-run              # download SwayOSD, check the patch still applies
shellcheck install.sh uninstall.sh bin/* scripts/*.sh   # several infos/warnings pre-exist
luac -p config/hypr/hyde-qs.lua
```

Compare the repo against a live machine before saving changes. Render `@HOME@` first, then diff, e.g.
`diff <(sed "s#@HOME@#$HOME#g" config/waybar/layouts/Unified.jsonc) ~/.config/waybar/config.jsonc`.
Live `*.bak*` files and HyDE-generated ones (`waybar/theme.css`, `waybar/includes/`) are not repo
content (`.gitignore` covers them).

## Gotchas (all hit in practice)

- `config/quickshell/notifications/Center.qml` calls `~/.config/hyde/scripts/control-center.sh`
  for its Wi-Fi/Bluetooth/DND/Awake toggles; it was once missing from the repo.
- Waybar's `image` module keeps the last picture when its command prints nothing, so
  `hyde-qs-media cover` prints a non-existent `none.png` path to clear the album art.
- The Waybar camera/touchpad/profile modules call `hw` from the dotfiles repo; they stay hidden without it.
- `config/hyde/scripts/hyprlock.sh` + `hyprlock-safe.py` override HyDE's lock script on purpose:
  they keep hyprlock but disable PAM-backed previews.
- No location, timezone or credentials in the repo: the weather location comes from the files above,
  Google Calendar OAuth stays in `~/.config/hyde-calendar/` (see `SECURITY.md`).
