#!/usr/bin/env bash

has_command() {
  command -v "$1" > /dev/null 2>&1
}

require_command() {
  local cmd="$1"
  local message="${2:-missing command: $cmd}"

  has_command "$cmd" || {
    echo "$message" >&2
    return 1
  }
}

run() {
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    printf '+'
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    return 0
  fi

  "$@"
}

load_packages() {
  local file

  for file in "$@"; do
    [ -f "$file" ] || continue
    grep -Ev '^[[:space:]]*(#|$)' "$file"
  done | awk '!seen[$0]++'
}

run_dry_runnable_script() {
  local script="$1"
  shift

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    "$script" --dry-run "$@"
    return 0
  fi

  "$script" "$@"
}
