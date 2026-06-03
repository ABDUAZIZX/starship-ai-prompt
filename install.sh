#!/usr/bin/env bash
#
# install.sh — Set up the AI-aware Starship prompt (Ollama + GPU segments).
#
# Safe by design:
#   - Never overwrites an existing starship.toml without a timestamped backup.
#   - Asks for confirmation before touching existing files.
#   - Verifies required tools and warns about optional ones.
#   - Installs the helper scripts into ~/.local/bin (no sudo, no system files).
#
# Usage:
#   ./install.sh            # interactive
#   ./install.sh --yes      # non-interactive (assume "yes" to prompts)
#
set -euo pipefail

# ── Resolve paths ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
# Honour a custom STARSHIP_CONFIG if the user already exports one.
STARSHIP_TOML="${STARSHIP_CONFIG:-$CONFIG_DIR/starship.toml}"

ASSUME_YES=0
[ "${1:-}" = "--yes" ] || [ "${1:-}" = "-y" ] && ASSUME_YES=1

# ── Tiny output helpers ──────────────────────────────────────────────
info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

backup() {
    # backup <file> — copy to <file>.bak.<timestamp> if it exists
    [ -e "$1" ] || return 0
    local b
    b="$1.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p -- "$1" "$b"
    ok "Backed up existing file → $b"
}

# ── 1. Dependency checks ─────────────────────────────────────────────
info "Checking dependencies..."

command -v starship >/dev/null 2>&1 \
    || die "starship not found. Install it first: https://starship.rs/guide/#🚀-installation"
ok "starship found"

command -v curl >/dev/null 2>&1 \
    || die "curl is required by the Ollama segment."
ok "curl found"

# Optional — segments self-hide via their 'when =' guard if absent.
command -v nvidia-smi >/dev/null 2>&1 \
    && ok "nvidia-smi found (GPU segment will show)" \
    || warn "nvidia-smi not found — GPU segment will stay hidden (fine on non-NVIDIA)."

command -v systemctl >/dev/null 2>&1 \
    || warn "systemctl not found — the Ollama segment expects a systemd 'ollama' service and will stay hidden."

warn "A Nerd Font is required for the icons (   󰒋 󰢮 …). See: https://www.nerdfonts.com/"

# ── 2. Install helper scripts ────────────────────────────────────────
info "Installing helper scripts into $BIN_DIR ..."
mkdir -p -- "$BIN_DIR"
for f in starship-ollama starship-gpu; do
    src="$SCRIPT_DIR/bin/$f"
    dst="$BIN_DIR/$f"
    [ -f "$src" ] || die "Missing source script: $src"
    backup "$dst"
    install -m 0755 -- "$src" "$dst"
    ok "Installed $dst"
done

case ":$PATH:" in
    *":$BIN_DIR:"*) : ;;
    *) warn "$BIN_DIR is not on your PATH. Add it in your shell rc:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# ── 3. Install starship.toml ─────────────────────────────────────────
info "Installing prompt config → $STARSHIP_TOML"
mkdir -p -- "$(dirname -- "$STARSHIP_TOML")"

if [ -e "$STARSHIP_TOML" ]; then
    if confirm "A starship.toml already exists. Overwrite it (a backup will be made)?"; then
        backup "$STARSHIP_TOML"
        install -m 0644 -- "$SCRIPT_DIR/starship.toml" "$STARSHIP_TOML"
        ok "Config installed"
    else
        warn "Skipped config. Merge manually from: $SCRIPT_DIR/starship.toml"
    fi
else
    install -m 0644 -- "$SCRIPT_DIR/starship.toml" "$STARSHIP_TOML"
    ok "Config installed"
fi

# ── 4. Verify shell init ─────────────────────────────────────────────
SHELL_NAME="$(basename -- "${SHELL:-}")"
case "$SHELL_NAME" in
    zsh)  RC="$HOME/.zshrc";  INIT='eval "$(starship init zsh)"'  ;;
    bash) RC="$HOME/.bashrc"; INIT='eval "$(starship init bash)"' ;;
    *)    RC=""; INIT='' ;;
esac

if [ -n "$RC" ]; then
    if ! grep -q 'starship init' "$RC" 2>/dev/null; then
        warn "Starship is not initialised in $RC. Add this line:"
        printf '    %s\n' "$INIT"
    else
        ok "Starship already initialised in $RC"
    fi
fi

echo
ok "Done. Open a new terminal (or 'exec $SHELL_NAME') to see the prompt."
