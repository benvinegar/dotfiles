#!/usr/bin/env bash
set -euo pipefail

DOTFILES_PI="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(cd "$DOTFILES_PI/.." && pwd -P)"
PI_AGENT="$HOME/.pi/agent"
SHARED_AGENTS="$HOME/.agents"
export DOTFILES_INSTALL_LOG_PREFIX='  '

# shellcheck source=../scripts/lib/install-helpers.sh
. "$DOTFILES_ROOT/scripts/lib/install-helpers.sh"

echo "Installing pi dotfiles..."
echo "  Pi source: $DOTFILES_PI"
echo "  Shared skills source: $DOTFILES_ROOT/skills"
echo "  Pi themes source: $DOTFILES_PI/themes"
echo "  Pi target: $PI_AGENT"
echo "  Shared skills target: $SHARED_AGENTS/skills"
echo "  Pi themes target: $PI_AGENT/themes"

mkdir -p "$PI_AGENT" "$SHARED_AGENTS"

link_path "$DOTFILES_ROOT/skills" "$SHARED_AGENTS/skills"
link_path "$DOTFILES_PI/extensions" "$PI_AGENT/extensions"
link_path "$DOTFILES_PI/themes" "$PI_AGENT/themes"
link_path "$DOTFILES_PI/settings.json" "$PI_AGENT/settings.json"

if [ -f "$DOTFILES_PI/instructions.md" ]; then
  link_path "$DOTFILES_PI/instructions.md" "$PI_AGENT/instructions.md"
fi

# Install npm dependencies for extensions that have a package.json
for pkg in "$DOTFILES_PI"/extensions/*/package.json; do
  [ -f "$pkg" ] || continue
  dir="$(dirname "$pkg")"
  echo "  Installing npm deps in $(basename "$dir")/"
  (cd "$dir" && npm install --silent)
done

echo "Done!"
