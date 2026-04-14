#!/usr/bin/env sh

if [ -n "${DOTFILES_SHELL_INIT_LOADED:-}" ]; then
  return 0 2> /dev/null || exit 0
fi
DOTFILES_SHELL_INIT_LOADED=1
export DOTFILES_SHELL_INIT_LOADED

DOTFILES_SHELL_DIR="${DOTFILES_SHELL_DIR:-$HOME/.config/dotfiles/shell}"
DOTFILES_PATH_SCRIPT="$DOTFILES_SHELL_DIR/path.sh"
DOTFILES_PLATFORM_SCRIPT="$DOTFILES_SHELL_DIR/platform.sh"

# Load PATH setup first so later shell snippets see the expected binaries.
if [ -f "$DOTFILES_PATH_SCRIPT" ]; then
  # shellcheck source=/dev/null
  . "$DOTFILES_PATH_SCRIPT"
fi

# Load shared portability helpers next so later snippets can reuse them.
if [ -f "$DOTFILES_PLATFORM_SCRIPT" ]; then
  # shellcheck source=/dev/null
  . "$DOTFILES_PLATFORM_SCRIPT"
fi

# Then load the rest of the shared shell snippets.
for script in "$DOTFILES_SHELL_DIR"/*.sh; do
  [ -f "$script" ] || continue
  [ "$script" = "$DOTFILES_SHELL_DIR/init.sh" ] && continue
  [ "$script" = "$DOTFILES_PATH_SCRIPT" ] && continue
  [ "$script" = "$DOTFILES_PLATFORM_SCRIPT" ] && continue
  # shellcheck source=/dev/null
  . "$script"
done

unset script DOTFILES_PATH_SCRIPT DOTFILES_PLATFORM_SCRIPT
