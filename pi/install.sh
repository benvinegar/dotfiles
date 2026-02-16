#!/usr/bin/env bash
set -euo pipefail

DOTFILES_PI="$(cd "$(dirname "$0")" && pwd)"
PI_AGENT="$HOME/.pi/agent"

echo "Installing pi dotfiles..."
echo "  Source: $DOTFILES_PI"
echo "  Target: $PI_AGENT"

mkdir -p "$PI_AGENT"

link() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    echo "  Backing up existing $dst -> ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi

  ln -s "$src" "$dst"
  echo "  Linked $dst -> $src"
}

link "$DOTFILES_PI/extensions" "$PI_AGENT/extensions"
link "$DOTFILES_PI/skills" "$PI_AGENT/skills"
link "$DOTFILES_PI/settings.json" "$PI_AGENT/settings.json"
link "$DOTFILES_PI/instructions.md" "$PI_AGENT/instructions.md"

# Install npm dependencies for extensions that have a package.json
for pkg in "$DOTFILES_PI"/extensions/*/package.json; do
  [ -f "$pkg" ] || continue
  dir="$(dirname "$pkg")"
  echo "  Installing npm deps in $(basename "$dir")/"
  (cd "$dir" && npm install --silent)
done

echo "Done!"
