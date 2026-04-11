#!/usr/bin/env sh

case $- in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

command -v zoxide >/dev/null 2>&1 || return 0 2>/dev/null || exit 0

if [ -n "${ZSH_VERSION:-}" ]; then
  eval "$(zoxide init zsh)"
elif [ -n "${BASH_VERSION:-}" ]; then
  eval "$(zoxide init bash)"
fi

zd() {
  if [ "$#" -eq 0 ]; then
    builtin cd ~ && return
  elif [ -d "$1" ]; then
    builtin cd "$@"
  else
    z "$@" && pwd || echo "Error: Directory not found"
  fi
}

alias cd='zd'
