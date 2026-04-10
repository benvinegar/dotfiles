#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"

link() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    local current
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      echo "already linked: $dst"
      return 0
    fi
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "${dst}.bak"
    echo "backed up: $dst -> ${dst}.bak"
  fi

  ln -s "$src" "$dst"
  echo "linked: $dst -> $src"
}

seed_copy() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    rm -f "$dst"
    cp "$src" "$dst"
    echo "replaced symlink with local copy: $dst <- $src"
    return 0
  fi

  if [ -e "$dst" ]; then
    echo "keeping existing local file: $dst"
    return 0
  fi

  cp "$src" "$dst"
  echo "copied: $dst <- $src"
}

echo "Installing dotfiles links from: $DOTFILES_ROOT"

# tmux
link "$DOTFILES_ROOT/tmux/tmux.conf" "$HOME/.tmux.conf"

# tmux helper scripts
mkdir -p "$HOME/bin"
for script in \
  codex-tmux-notify.sh \
  tmux-agent-daemon.sh \
  tmux-agent-overview.sh \
  tmux-agent-resync.sh \
  tmux-before-enter.sh \
  tmux-busy-spinner.sh \
  tmux-detect-codex-pane.sh \
  tmux-sys-stats.sh \
  tmux-watch-pi-turn.sh

do
  chmod 755 "$DOTFILES_ROOT/tmux/bin/$script"
  link "$DOTFILES_ROOT/tmux/bin/$script" "$HOME/bin/$script"
done

# codex
# Copy instead of symlink: Codex mutates its live config.toml during normal TUI use.
seed_copy "$DOTFILES_ROOT/codex/config.toml" "$HOME/.codex/config.toml"

# shared agent skills
link "$DOTFILES_ROOT/skills" "$HOME/.agents/skills"
link "$DOTFILES_ROOT/skills" "$HOME/.claude/skills"

cat <<'EOF'

Done.

Reload tmux in existing sessions:
  tmux source-file ~/.tmux.conf

For pi extensions/settings:
  ./pi/install.sh
EOF
