#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"
PACKAGES_FILE="$DOTFILES_ROOT/packages/common.txt"
DRY_RUN=0

usage() {
  cat << 'EOF'
Usage: ./bootstrap.sh [--dry-run]

Install terminal tools managed by this dotfiles repo.
- macOS: uses Homebrew
- Arch Linux: uses pacman
- Package source of truth: packages/common.txt

Options:
  --dry-run   Print the install command without running it
  -h, --help  Show this help
EOF
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
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
  grep -Ev '^[[:space:]]*(#|$)' "$PACKAGES_FILE"
}

install_arch() {
  local package
  local -a packages=()

  if ! command -v pacman > /dev/null 2>&1; then
    echo "error: pacman not found; this bootstrap currently supports Arch Linux on Linux." >&2
    exit 1
  fi

  while IFS= read -r package; do
    packages+=("$package")
  done < <(load_packages)

  if [ "${#packages[@]}" -eq 0 ]; then
    echo "No packages configured in $PACKAGES_FILE"
    return 0
  fi

  echo "Installing packages from: $PACKAGES_FILE"
  run sudo pacman -S --needed "${packages[@]}"
}

install_macos() {
  local package
  local -a packages=()

  if ! command -v brew > /dev/null 2>&1; then
    echo "error: Homebrew is required on macOS before running bootstrap.sh" >&2
    echo "Install it from https://brew.sh and rerun this script." >&2
    exit 1
  fi

  while IFS= read -r package; do
    packages+=("$package")
  done < <(load_packages)

  if [ "${#packages[@]}" -eq 0 ]; then
    echo "No packages configured in $PACKAGES_FILE"
    return 0
  fi

  echo "Installing packages from: $PACKAGES_FILE"
  run brew install "${packages[@]}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

case "$(uname -s)" in
  Darwin)
    install_macos
    ;;
  Linux)
    install_arch
    ;;
  *)
    echo "error: unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

if [ -x "$DOTFILES_ROOT/zsh/bootstrap.sh" ]; then
  echo
  if [ "$DRY_RUN" -eq 1 ]; then
    "$DOTFILES_ROOT/zsh/bootstrap.sh" --dry-run
  else
    "$DOTFILES_ROOT/zsh/bootstrap.sh"
  fi
fi

cat << 'EOF'

Bootstrap complete.

Next step:
  ./install.sh
EOF
