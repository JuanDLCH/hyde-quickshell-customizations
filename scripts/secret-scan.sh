#!/usr/bin/env bash
# Fail if tracked files (or staged ones, with --staged) contain anything that looks like a secret
# or personal data. Run before every push; CI-friendly (exit 1 on findings).
set -uo pipefail
cd "$(dirname "$0")/.."
if [[ ${1:-} == --staged ]]; then files=$(git diff --cached --name-only --diff-filter=AM)
else files=$(git ls-files); fi
[[ -n $files ]] || exit 0

fail=0
# forbidden file names
bad=$(printf '%s\n' "$files" | grep -E '(^|/)(token|client|credentials|client_secret.*)\.json$|\.(pem|key|p12)$|\.env$|\.bak' || true)
[[ -z $bad ]] || { echo "forbidden files:"; echo "$bad"; fail=1; }

# content patterns (extended regex)
pat='(client_secret|refresh_token|access_token|api[_-]?key|password)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9_./+-]{12,}'
pat+='|AIza[0-9A-Za-z_-]{30,}|ghp_[0-9A-Za-z]{30,}|github_pat_[0-9A-Za-z_]{30,}|sk-[A-Za-z0-9]{20,}|xox[bap]-[0-9A-Za-z-]+'
pat+='|-----BEGIN [A-Z ]*PRIVATE KEY-----|[0-9]{6,}-[0-9a-z]{20,}\.apps\.googleusercontent\.com'
pat+='|/home/[a-z0-9_-]+/|[A-Za-z0-9._%+-]+@(gmail|hotmail|outlook|yahoo)\.com'
hits=$(printf '%s\n' "$files" | xargs -d '\n' grep -InE "$pat" 2>/dev/null | grep -v '^scripts/secret-scan.sh:' || true)
if [[ -n $hits ]]; then echo "suspicious content:"; echo "$hits"; fail=1; fi

((fail)) && { echo "secret-scan: FAILED"; exit 1; }
echo "secret-scan: clean ($(printf '%s\n' "$files" | wc -l) files)"
