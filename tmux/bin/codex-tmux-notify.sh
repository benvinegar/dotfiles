#!/usr/bin/env bash
set -euo pipefail

# Codex invokes notify hook as: <argv...> '<json-payload>'
# We only care about turn completion events.
payload="${*: -1}"

case "$payload" in
  *'"type":"agent-turn-complete"'*) ;;
  *) exit 0 ;;
esac

pane_id="${TMUX_PANE:-}"
[ -n "$pane_id" ] || exit 0

state_dir="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
rm -f "$state_dir/codex-busy-${pane_id#%}.ts" 2> /dev/null || true

tmux select-pane -t "$pane_id" -T codex:idle > /dev/null 2>&1 || true
