#!/usr/bin/env sh

case $- in
  *i*) ;;
  *) return 0 2> /dev/null || exit 0 ;;
esac

command -v eza > /dev/null 2>&1 || return 0 2> /dev/null || exit 0

export EZA_CONFIG_DIR="${EZA_CONFIG_DIR:-$HOME/.config/eza}"

eza() {
  (
    unset LS_COLORS EZA_COLORS
    export EZA_CONFIG_DIR="${EZA_CONFIG_DIR:-$HOME/.config/eza}"
    command eza "$@"
  )
}

alias ls='eza --group-directories-first --icons=auto'
alias l='eza --group-directories-first --icons=auto'
alias la='eza -a --group-directories-first --icons=auto'
alias ll='eza -la --group-directories-first --git --icons=auto'
alias lt='eza --tree --level=2 --long --git --icons=auto'
