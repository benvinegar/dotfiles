#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
lima_load_defaults

command -v limactl > /dev/null 2>&1 || {
  echo "missing command: limactl" >&2
  exit 1
}

sync_instance_shell_to_zsh() {
  [ -f "$INSTANCE_CONFIG" ] || return 0
  grep -q 'shell: /usr/bin/zsh' "$INSTANCE_CONFIG" && return 0

  python3 - "$INSTANCE_CONFIG" << 'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
needle = 'shell: /bin/bash'
if needle not in text:
    raise SystemExit(0)
p.write_text(text.replace(needle, 'shell: /usr/bin/zsh', 1))
PY

  echo "Restarting $INSTANCE_NAME so limactl shell opens zsh"
  limactl stop "$INSTANCE_NAME"
  limactl start "$INSTANCE_NAME"
}

limactl shell "$INSTANCE_NAME" -- bash -lc "rm -rf $(printf %q "$REMOTE_DOTFILES_PATH")"
limactl copy -r --backend=scp "$DOTFILES_ROOT" "$INSTANCE_NAME:$REMOTE_DOTFILES_PATH"
limactl shell "$INSTANCE_NAME" -- bash -lc "cd $(printf %q "$REMOTE_DOTFILES_PATH") && ./arch/setup.sh --noconfirm && ./install.sh"
sync_instance_shell_to_zsh

cat << EOF

Dotfiles installed into $INSTANCE_NAME.

Open a shell:
  limactl shell $INSTANCE_NAME
EOF
