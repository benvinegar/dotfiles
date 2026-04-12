#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OH_MY_ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
export DRY_RUN=0

# shellcheck source=../scripts/lib/bootstrap-helpers.sh
. "$DOTFILES_ROOT/scripts/lib/bootstrap-helpers.sh"

usage() {
  cat << 'EOF'
Usage: ./zsh/bootstrap.sh [--dry-run]

Bootstrap Zsh dependencies used by this dotfiles repo.
- Clones Oh My Zsh core if missing
- Repo-managed themes/plugins are wired later by install.sh

Options:
  --dry-run   Print what would happen without changing anything
  -h, --help  Show this help
EOF
}

ensure_repo() {
  local name="$1"
  local repo="$2"
  local dst="$3"

  if [ -d "$dst/.git" ]; then
    echo "keeping existing $name: $dst"
    return 0
  fi

  if [ -e "$dst" ]; then
    run mv "$dst" "${dst}.bak"
    if [ "$DRY_RUN" -eq 0 ]; then
      echo "backed up existing $name path: $dst -> ${dst}.bak"
    fi
  fi

  run mkdir -p "$(dirname "$dst")"
  echo "installing $name: $dst"
  run git clone --depth=1 "$repo" "$dst"
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

if ! has_command zsh; then
  echo "warning: zsh not found; skipping Oh My Zsh bootstrap"
  exit 0
fi

require_command git "error: git is required to bootstrap Oh My Zsh" || exit 1

echo "Bootstrapping Zsh dependencies..."
ensure_repo "Oh My Zsh" "https://github.com/ohmyzsh/ohmyzsh.git" "$OH_MY_ZSH_DIR"

cat << 'EOF'

Install note:
  Run ./install.sh to wire the repo-managed Oh My Zsh custom dir and ~/.p10k.zsh.
EOF

cat << 'EOF'

Font note:
  Terminal configs in this repo expect CaskaydiaMono Nerd Font.
  - Arch: sudo pacman -S --needed ttf-cascadia-mono-nerd
  - macOS: install a compatible Caskaydia/Cascadia Nerd Font or adjust your terminal config
EOF
