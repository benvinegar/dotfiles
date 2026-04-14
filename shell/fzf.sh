#!/usr/bin/env sh

case $- in
  *i*) ;;
  *) return 0 2> /dev/null || exit 0 ;;
esac

command -v fzf > /dev/null 2>&1 || return 0 2> /dev/null || exit 0

load_fzf_from_binary() {
  if [ -n "${ZSH_VERSION:-}" ]; then
    fzf_shell_init="$(fzf --zsh 2> /dev/null || true)"
  elif [ -n "${BASH_VERSION:-}" ]; then
    fzf_shell_init="$(fzf --bash 2> /dev/null || true)"
  else
    return 1
  fi

  [ -n "$fzf_shell_init" ] || return 1
  eval "$fzf_shell_init"
}

load_fzf_from_package_files() {
  if command -v dotfiles_first_existing_dir > /dev/null 2>&1; then
    fzf_shell_dir="$(dotfiles_first_existing_dir \
      "${FZF_SHELL_DIR:-}" \
      /opt/homebrew/opt/fzf/shell \
      /usr/local/opt/fzf/shell \
      /usr/share/fzf || true)"
  else
    for fzf_shell_dir in \
      "${FZF_SHELL_DIR:-}" \
      /opt/homebrew/opt/fzf/shell \
      /usr/local/opt/fzf/shell \
      /usr/share/fzf
    do
      [ -n "$fzf_shell_dir" ] || continue
      [ -d "$fzf_shell_dir" ] && break
      fzf_shell_dir=""
    done
  fi

  if [ -z "$fzf_shell_dir" ] && command -v dotfiles_brew_prefix > /dev/null 2>&1; then
    brew_prefix="$(dotfiles_brew_prefix fzf || true)"
    if [ -n "$brew_prefix" ] && command -v dotfiles_first_existing_dir > /dev/null 2>&1; then
      fzf_shell_dir="$(dotfiles_first_existing_dir "$brew_prefix/shell" || true)"
    elif [ -n "$brew_prefix" ] && [ -d "$brew_prefix/shell" ]; then
      fzf_shell_dir="$brew_prefix/shell"
    fi
  fi

  [ -n "$fzf_shell_dir" ] || return 1

  if [ -n "${ZSH_VERSION:-}" ]; then
    [ -f "$fzf_shell_dir/completion.zsh" ] && . "$fzf_shell_dir/completion.zsh"
    [ -f "$fzf_shell_dir/key-bindings.zsh" ] && . "$fzf_shell_dir/key-bindings.zsh"
    return 0
  fi

  if [ -n "${BASH_VERSION:-}" ]; then
    [ -f "$fzf_shell_dir/completion.bash" ] && . "$fzf_shell_dir/completion.bash"
    [ -f "$fzf_shell_dir/key-bindings.bash" ] && . "$fzf_shell_dir/key-bindings.bash"
    return 0
  fi

  return 1
}

load_fzf_from_binary || load_fzf_from_package_files || true

unset fzf_shell_init fzf_shell_dir brew_prefix
unset -f load_fzf_from_binary load_fzf_from_package_files 2> /dev/null || true

if command -v bat > /dev/null 2>&1; then
  alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
fi
