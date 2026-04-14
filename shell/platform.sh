#!/usr/bin/env sh

dotfiles_has_command() {
  command -v "$1" > /dev/null 2>&1
}

dotfiles_os() {
  uname -s 2> /dev/null
}

dotfiles_is_macos() {
  [ "$(dotfiles_os)" = "Darwin" ]
}

dotfiles_is_linux() {
  [ "$(dotfiles_os)" = "Linux" ]
}

dotfiles_source_if_exists() {
  [ -r "$1" ] || return 1
  # shellcheck source=/dev/null
  . "$1"
}

dotfiles_first_existing_dir() {
  for dotfiles_dir_candidate in "$@"; do
    [ -n "$dotfiles_dir_candidate" ] || continue
    if [ -d "$dotfiles_dir_candidate" ]; then
      printf '%s\n' "$dotfiles_dir_candidate"
      return 0
    fi
  done
  return 1
}

dotfiles_brew_prefix() {
  [ -n "${1:-}" ] || return 1
  dotfiles_has_command brew || return 1
  brew --prefix "$1" 2> /dev/null
}
