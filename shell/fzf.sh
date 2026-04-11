#!/usr/bin/env sh

case $- in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

command -v fzf >/dev/null 2>&1 || return 0 2>/dev/null || exit 0

if [ -n "${ZSH_VERSION:-}" ]; then
  [ -f /usr/share/fzf/completion.zsh ] && . /usr/share/fzf/completion.zsh
  [ -f /usr/share/fzf/key-bindings.zsh ] && . /usr/share/fzf/key-bindings.zsh
elif [ -n "${BASH_VERSION:-}" ]; then
  [ -f /usr/share/fzf/completion.bash ] && . /usr/share/fzf/completion.bash
  [ -f /usr/share/fzf/key-bindings.bash ] && . /usr/share/fzf/key-bindings.bash
fi

if command -v bat >/dev/null 2>&1; then
  alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
fi
