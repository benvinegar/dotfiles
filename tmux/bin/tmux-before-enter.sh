#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
pane_pid="${2:-}"
pane_title="${3:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/agent-state.sh
. "$SCRIPT_DIR/lib/agent-state.sh"

[ -n "$pane_id" ] || exit 0

# First, resync this pane's title based on actual child process state.
"${HOME}/bin/tmux-agent-resync.sh" "$pane_id" "$pane_pid" "$pane_title"

# If this is an agent pane, mark/start busy handling on Enter.
current_title="$(tmux display-message -t "$pane_id" -p '#{pane_title}' 2> /dev/null || true)"
case "$current_title" in
  codex:idle | codex:busy)
    tmux_agent_ensure_state_dir > /dev/null
    touch "$(tmux_agent_busy_stamp_file codex "$pane_id")" 2> /dev/null || true
    tmux_agent_set_title "$pane_id" codex:busy
    ;;
  pi:idle | pi:busy)
    "${HOME}/bin/tmux-watch-pi-turn.sh" "$pane_id" "$pane_pid"
    ;;
  opencode:idle | opencode:busy)
    tmux_agent_ensure_state_dir > /dev/null
    touch "$(tmux_agent_busy_stamp_file opencode "$pane_id")" 2> /dev/null || true
    tmux_agent_set_title "$pane_id" opencode:busy
    ;;
esac
