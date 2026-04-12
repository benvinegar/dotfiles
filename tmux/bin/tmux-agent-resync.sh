#!/usr/bin/env bash
set -euo pipefail

detector="${HOME}/bin/tmux-detect-codex-pane.sh"

if [ "${1:-}" != "" ] && [ "${2:-}" != "" ]; then
  # Fast path: single pane passed in by tmux hook.
  "$detector" "$1" "$2" "${3:-}"
  exit 0
fi

# Full resync across all panes.
tmux list-panes -a -F '#{pane_id} #{pane_pid} #{pane_title}' \
  | while read -r pane pid title; do
    "$detector" "$pane" "$pid" "$title"
  done
