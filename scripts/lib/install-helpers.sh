#!/usr/bin/env bash

install_log_prefix="${DOTFILES_INSTALL_LOG_PREFIX:-}"

install_log() {
  printf '%s%s\n' "$install_log_prefix" "$*"
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

link_path() {
  local src="$1"
  local dst="$2"

  ensure_parent_dir "$dst"

  if [ -L "$dst" ]; then
    local current
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      install_log "already linked: $dst"
      return 0
    fi
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "${dst}.bak"
    install_log "backed up: $dst -> ${dst}.bak"
  fi

  ln -s "$src" "$dst"
  install_log "linked: $dst -> $src"
}

seed_copy_path() {
  local src="$1"
  local dst="$2"

  ensure_parent_dir "$dst"

  if [ -L "$dst" ]; then
    rm -f "$dst"
    cp "$src" "$dst"
    install_log "replaced symlink with local copy: $dst <- $src"
    return 0
  fi

  if [ -e "$dst" ]; then
    install_log "keeping existing local file: $dst"
    return 0
  fi

  cp "$src" "$dst"
  install_log "copied: $dst <- $src"
}
