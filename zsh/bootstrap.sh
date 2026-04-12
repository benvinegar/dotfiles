#!/usr/bin/env bash
set -euo pipefail

OH_MY_ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"
P10K_DIR="$ZSH_CUSTOM_DIR/themes/powerlevel10k"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./zsh/bootstrap.sh [--dry-run]

Bootstrap Zsh prompt dependencies used by this dotfiles repo.
- Clones Oh My Zsh if missing
- Clones Powerlevel10k if missing
- Seeds ~/.zshrc from the Oh My Zsh template on fresh machines

Options:
  --dry-run   Print what would happen without changing anything
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

ensure_repo() {
  local name="$1"
  local repo="$2"
  local dst="$3"

  if [ -d "$dst/.git" ]; then
    echo "keeping existing $name: $dst"
    return 0
  fi

  if [ -e "$dst" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '+ mv %q %q\n' "$dst" "${dst}.bak"
    else
      mv "$dst" "${dst}.bak"
      echo "backed up existing $name path: $dst -> ${dst}.bak"
    fi
  fi

  run mkdir -p "$(dirname "$dst")"
  echo "installing $name: $dst"
  run git clone --depth=1 "$repo" "$dst"
}

seed_zshrc() {
  local template="$OH_MY_ZSH_DIR/templates/zshrc.zsh-template"
  local dst="$HOME/.zshrc"
  local tmp

  if [ -e "$dst" ]; then
    echo "keeping existing $dst"
    if ! grep -Fq 'powerlevel10k/powerlevel10k' "$dst" 2>/dev/null; then
      echo "note: $dst does not appear to load powerlevel10k; adjust it manually if needed"
    fi
    return 0
  fi

  if [ ! -f "$template" ]; then
    echo "warning: missing Oh My Zsh template: $template" >&2
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '+ sed %q > %q\n' 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$dst"
    echo "would seed $dst from the Oh My Zsh template"
    return 0
  fi

  tmp="$(mktemp)"
  sed 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$template" > "$tmp"
  mv "$tmp" "$dst"
  echo "seeded $dst from the Oh My Zsh template"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
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

if ! command -v zsh >/dev/null 2>&1; then
  echo "warning: zsh not found; skipping Oh My Zsh / Powerlevel10k bootstrap"
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required to bootstrap Oh My Zsh / Powerlevel10k" >&2
  exit 1
fi

echo "Bootstrapping Zsh prompt dependencies..."
ensure_repo "Oh My Zsh" "https://github.com/ohmyzsh/ohmyzsh.git" "$OH_MY_ZSH_DIR"
ensure_repo "Powerlevel10k" "https://github.com/romkatv/powerlevel10k.git" "$P10K_DIR"
seed_zshrc

cat <<'EOF'

Font note:
  Terminal configs in this repo expect CaskaydiaMono Nerd Font.
  - Arch: sudo pacman -S --needed ttf-cascadia-mono-nerd
  - macOS: install a compatible Caskaydia/Cascadia Nerd Font or adjust your terminal config
EOF
