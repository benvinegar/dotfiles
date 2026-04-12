#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/lib/install-helpers.sh
. "$DOTFILES_ROOT/scripts/lib/install-helpers.sh"

ensure_block() {
  local file="$1"
  local begin_marker="$2"
  local end_marker="$3"
  local body="$4"
  local tmp replaced in_block

  mkdir -p "$(dirname "$file")"
  [ -e "$file" ] || touch "$file"

  tmp="$(mktemp)"
  replaced=0
  in_block=0

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_block" -eq 0 ] && [ "$line" = "$begin_marker" ]; then
      printf '%s\n%s\n%s\n' "$begin_marker" "$body" "$end_marker" >> "$tmp"
      replaced=1
      in_block=1
      continue
    fi

    if [ "$in_block" -eq 1 ]; then
      if [ "$line" = "$end_marker" ]; then
        in_block=0
      fi
      continue
    fi

    printf '%s\n' "$line" >> "$tmp"
  done < "$file"

  if [ "$replaced" -eq 0 ]; then
    [ -s "$tmp" ] && printf '\n' >> "$tmp"
    printf '%s\n%s\n%s\n' "$begin_marker" "$body" "$end_marker" >> "$tmp"
  fi

  if cmp -s "$file" "$tmp"; then
    rm -f "$tmp"
    echo "already configured: $file"
    return 0
  fi

  mv "$tmp" "$file"
  echo "updated: $file"
}

echo "Installing dotfiles links from: $DOTFILES_ROOT"

# tmux
link_path "$DOTFILES_ROOT/tmux/tmux.conf" "$HOME/.tmux.conf"

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
  tmux-watch-pi-turn.sh; do
  chmod 755 "$DOTFILES_ROOT/tmux/bin/$script"
  link_path "$DOTFILES_ROOT/tmux/bin/$script" "$HOME/bin/$script"
done

# codex
# Copy instead of symlink: Codex mutates its live config.toml during normal TUI use.
seed_copy_path "$DOTFILES_ROOT/codex/config.toml" "$HOME/.codex/config.toml"

# shared shell config
link_path "$DOTFILES_ROOT/shell" "$HOME/.config/dotfiles/shell"
link_path "$DOTFILES_ROOT/oh-my-zsh-custom" "$HOME/.config/dotfiles/oh-my-zsh-custom"
link_path "$DOTFILES_ROOT/zsh/oh-my-zsh.zsh" "$HOME/.config/dotfiles/zsh/oh-my-zsh.zsh"
link_path "$DOTFILES_ROOT/eza/theme.yml" "$HOME/.config/eza/theme.yml"
link_path "$DOTFILES_ROOT/zsh/p10k.zsh" "$HOME/.p10k.zsh"
shell_init='[ -f "$HOME/.config/dotfiles/shell/init.sh" ] && . "$HOME/.config/dotfiles/shell/init.sh"'
omz_init='[ -f "$HOME/.config/dotfiles/zsh/oh-my-zsh.zsh" ] && source "$HOME/.config/dotfiles/zsh/oh-my-zsh.zsh"'
p10k_init='[ -f "$HOME/.p10k.zsh" ] && source "$HOME/.p10k.zsh"'
ensure_block "$HOME/.bashrc" "# >>> dotfiles shell init >>>" "# <<< dotfiles shell init <<<" "$shell_init"
ensure_block "$HOME/.zshrc" "# >>> dotfiles shell init >>>" "# <<< dotfiles shell init <<<" "$shell_init"
ensure_block "$HOME/.zshrc" "# >>> dotfiles oh-my-zsh >>>" "# <<< dotfiles oh-my-zsh <<<" "$omz_init"
ensure_block "$HOME/.zshrc" "# >>> dotfiles p10k >>>" "# <<< dotfiles p10k <<<" "$p10k_init"

# shared agent skills
link_path "$DOTFILES_ROOT/skills" "$HOME/.agents/skills"
link_path "$DOTFILES_ROOT/skills" "$HOME/.claude/skills"

cat << 'EOF'

Done.

Reload tmux in existing sessions:
  tmux source-file ~/.tmux.conf

Reload your current shell:
  bash -> source ~/.bashrc
  zsh  -> source ~/.zshrc

Or start a fresh zsh session:
  exec zsh

For pi extensions/settings:
  ./pi/install.sh
EOF
