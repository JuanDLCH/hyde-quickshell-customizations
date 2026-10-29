# Security policy

This repo is public configuration, so it must never contain credentials or personal data.

- `scripts/secret-scan.sh` checks tracked (or `--staged`) files for tokens, OAuth secrets, private keys, e-mail addresses and absolute `/home/<user>` paths. Run it before every push.
- Google Calendar credentials (`client.json`, `token.json`) are created on your own machine under `~/.config/hyde-calendar/` and are git-ignored. Never copy them into this repo.
- Paths in the repo use the `@HOME@` placeholder; `install.sh` resolves it for the machine it runs on.
- `install.sh` backs up every file it replaces to `~/.local/state/hyde-qs/backup-*`, and `uninstall.sh` restores them.

Found something sensitive that slipped through? Open a private security advisory on GitHub instead of a public issue.
