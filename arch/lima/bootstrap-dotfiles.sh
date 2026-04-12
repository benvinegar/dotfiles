#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTANCE_NAME="${INSTANCE_NAME:-archlinux-arm}"
LIMA_USER_NAME="${LIMA_USER_NAME:-$(id -un)}"
LIMA_USER_HOME="${LIMA_USER_HOME:-/home/${LIMA_USER_NAME}.guest}"
REMOTE_DOTFILES_PATH="${REMOTE_DOTFILES_PATH:-$LIMA_USER_HOME/.dotfiles}"

command -v limactl >/dev/null 2>&1 || {
  echo "missing command: limactl" >&2
  exit 1
}

limactl shell "$INSTANCE_NAME" -- bash -lc "rm -rf $(printf %q "$REMOTE_DOTFILES_PATH")"
limactl copy -r --backend=scp "$DOTFILES_ROOT" "$INSTANCE_NAME:$REMOTE_DOTFILES_PATH"
limactl shell "$INSTANCE_NAME" -- bash -lc "cd $(printf %q "$REMOTE_DOTFILES_PATH") && ./arch/setup.sh --noconfirm && ./install.sh"

cat <<EOF

Dotfiles installed into $INSTANCE_NAME.

Open a shell:
  limactl shell $INSTANCE_NAME

Then start a fresh zsh session if needed:
  exec zsh
EOF
