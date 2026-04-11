#!/usr/bin/env sh

if [ -n "${DOTFILES_SHELL_INIT_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
DOTFILES_SHELL_INIT_LOADED=1
export DOTFILES_SHELL_INIT_LOADED

DOTFILES_SHELL_DIR="${DOTFILES_SHELL_DIR:-$HOME/.config/dotfiles/shell}"

for script in "$DOTFILES_SHELL_DIR"/*.sh; do
  [ -f "$script" ] || continue
  [ "$script" = "$DOTFILES_SHELL_DIR/init.sh" ] && continue
  . "$script"
done

unset script
