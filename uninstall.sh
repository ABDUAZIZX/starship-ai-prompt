#!/usr/bin/env bash
#
# uninstall.sh — Remove the helper scripts and their runtime caches.
# Leaves starship.toml in place (it may contain your own edits);
# restore an earlier *.bak.* backup manually if you want the old prompt back.
#
set -euo pipefail

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CACHE_DIR="${XDG_RUNTIME_DIR:-/tmp}"

ok() { printf '\033[1;32m✓\033[0m %s\n' "$*"; }

for f in starship-ollama starship-gpu; do
    rm -f -- "$BIN_DIR/$f"        && ok "Removed $BIN_DIR/$f"
done
rm -f -- "$CACHE_DIR/starship-ollama.cache" "$CACHE_DIR/starship-gpu.cache"
ok "Cleared caches"

printf '\nNote: starship.toml was left untouched at %s\n' "${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"
printf 'Restore a backup (starship.toml.bak.*) if you want the previous prompt.\n'
