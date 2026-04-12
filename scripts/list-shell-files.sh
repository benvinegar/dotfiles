#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

find . \
  \( \
  -path './.git' -o \
  -path './oh-my-zsh-custom/plugins' -o \
  -path './oh-my-zsh-custom/themes/powerlevel10k' \
  \) -prune -o \
  -type f \( -name '*.sh' -o -path './tmux/bin/*' \) -print \
  | sed 's#^\./##' \
  | sort
