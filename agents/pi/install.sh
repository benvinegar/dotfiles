#!/usr/bin/env bash
set -euo pipefail

DOTFILES_PI="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_AGENTS="$(cd "$DOTFILES_PI/.." && pwd -P)"
PI_AGENT="$HOME/.pi/agent"
SHARED_AGENTS="$HOME/.agents"

echo "Installing pi dotfiles..."
echo "  Pi source: $DOTFILES_PI"
echo "  Shared skills source: $DOTFILES_AGENTS/skills"
echo "  Pi target: $PI_AGENT"
echo "  Shared skills target: $SHARED_AGENTS/skills"

mkdir -p "$PI_AGENT" "$SHARED_AGENTS"

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

link "$DOTFILES_AGENTS/skills" "$SHARED_AGENTS/skills"
link "$DOTFILES_PI/extensions" "$PI_AGENT/extensions"
link "$DOTFILES_PI/settings.json" "$PI_AGENT/settings.json"

if [ -f "$DOTFILES_PI/instructions.md" ]; then
  link "$DOTFILES_PI/instructions.md" "$PI_AGENT/instructions.md"
fi

# Install npm dependencies for extensions that have a package.json
for pkg in "$DOTFILES_PI"/extensions/*/package.json; do
  [ -f "$pkg" ] || continue
  dir="$(dirname "$pkg")"
  echo "  Installing npm deps in $(basename "$dir")/"
  (cd "$dir" && npm install --silent)
done

echo "Done!"
