#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/agent-state.sh
. "$SCRIPT_DIR/lib/agent-state.sh"

# Codex invokes notify hook as: <argv...> '<json-payload>'
# We only care about turn completion events.
payload="${*: -1}"

case "$payload" in
  *'"type":"agent-turn-complete"'*) ;;
  *) exit 0 ;;
esac

pane_id="${TMUX_PANE:-}"
[ -n "$pane_id" ] || exit 0

rm -f "$(tmux_agent_busy_stamp_file codex "$pane_id")" 2> /dev/null || true

tmux_agent_set_title "$pane_id" codex:idle
