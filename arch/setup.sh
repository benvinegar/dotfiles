#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMON_PACKAGES_FILE="$DOTFILES_ROOT/packages/common.txt"
ARCH_PACKAGES_FILE="$DOTFILES_ROOT/packages/arch-extra.txt"
DRY_RUN=0
PACMAN_FLAGS=()

usage() {
  cat << 'EOF'
Usage: ./arch/setup.sh [--dry-run] [--noconfirm]

Install the Arch-specific toolchain used by this dotfiles repo.
This includes:
- common terminal tools from packages/common.txt
- Arch extras from packages/arch-extra.txt
- Zsh prompt dependencies via zsh/bootstrap.sh
- setting the login shell to zsh when available
- configuring npm global installs to use ~/.local

Options:
  --dry-run    Print the install command without running it
  --noconfirm  Pass --noconfirm to pacman for unattended installs
  -h, --help   Show this help
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
  local file

  for file in "$@"; do
    [ -f "$file" ] || continue
    grep -Ev '^[[:space:]]*(#|$)' "$file"
  done | awk '!seen[$0]++'
}

package_exists_in_pacman() {
  pacman -Si "$1" > /dev/null 2>&1
}

install_arch_packages() {
  local package
  local -a packages=() available_packages=() missing_packages=()

  while IFS= read -r package; do
    packages+=("$package")
  done < <(load_packages "$COMMON_PACKAGES_FILE" "$ARCH_PACKAGES_FILE")

  if [ "${#packages[@]}" -eq 0 ]; then
    echo "No packages configured in $COMMON_PACKAGES_FILE or $ARCH_PACKAGES_FILE"
    return 0
  fi

  for package in "${packages[@]}"; do
    if package_exists_in_pacman "$package"; then
      available_packages+=("$package")
    else
      missing_packages+=("$package")
    fi
  done

  echo "Installing Arch packages from:"
  echo "  - $COMMON_PACKAGES_FILE"
  echo "  - $ARCH_PACKAGES_FILE"

  if [ "${#missing_packages[@]}" -gt 0 ]; then
    printf 'warning: skipping unavailable Arch packages:'
    for package in "${missing_packages[@]}"; do
      printf ' %s' "$package"
    done
    printf '\n'
  fi

  if [ "${#available_packages[@]}" -eq 0 ]; then
    echo "No Arch packages available to install"
    return 0
  fi

  run sudo pacman -S --needed "${PACMAN_FLAGS[@]}" "${available_packages[@]}"
}

configure_login_shell() {
  local user_name current_shell zsh_bin

  user_name="$(id -un)"
  zsh_bin="$(command -v zsh || true)"

  if [ -z "$zsh_bin" ]; then
    echo "warning: zsh is not installed; leaving login shell unchanged"
    return 0
  fi

  current_shell="$(getent passwd "$user_name" | cut -d: -f7)"
  if [ "$current_shell" = "$zsh_bin" ]; then
    echo "Login shell already set: $zsh_bin"
    return 0
  fi

  echo "Setting login shell for $user_name: $current_shell -> $zsh_bin"
  run sudo chsh -s "$zsh_bin" "$user_name"
}

configure_npm_globals() {
  local prefix

  if ! command -v npm > /dev/null 2>&1; then
    echo "warning: npm is not installed; skipping npm global prefix setup"
    return 0
  fi

  prefix="$HOME/.local"
  echo "Configuring npm global prefix: $prefix"
  run npm config set prefix "$prefix"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --noconfirm)
      PACMAN_FLAGS+=(--noconfirm)
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

if [ "$(uname -s)" != "Linux" ]; then
  echo "error: ./arch/setup.sh only supports Linux guests" >&2
  exit 1
fi

if ! command -v pacman > /dev/null 2>&1; then
  echo "error: pacman not found; this script is intended for Arch Linux" >&2
  exit 1
fi

install_arch_packages
configure_login_shell
configure_npm_globals

echo
if [ "$DRY_RUN" -eq 1 ]; then
  printf '+ %q %q\n' "$DOTFILES_ROOT/zsh/bootstrap.sh" "--dry-run"
else
  "$DOTFILES_ROOT/zsh/bootstrap.sh"
fi

cat << 'EOF'

Arch setup complete.

Next step:
  ./install.sh

After install, start a fresh zsh session with:
  exec zsh
EOF
