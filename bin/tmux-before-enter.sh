#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
pane_pid="${2:-}"
pane_title="${3:-}"

[ -n "$pane_id" ] || exit 0

# First, resync this pane's title based on actual child process state.
"${HOME}/bin/tmux-agent-resync.sh" "$pane_id" "$pane_pid" "$pane_title"

# If this is an agent pane, mark/start busy handling on Enter.
current_title="$(tmux display-message -t "$pane_id" -p '#{pane_title}' 2>/dev/null || true)"
case "$current_title" in
  codex:idle|codex:busy)
    state_dir="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
    mkdir -p "$state_dir"
    touch "$state_dir/codex-busy-${pane_id#%}.ts" 2>/dev/null || true
    tmux select-pane -t "$pane_id" -T codex:busy >/dev/null 2>&1 || true
    ;;
  pi:idle|pi:busy)
    "${HOME}/bin/tmux-watch-pi-turn.sh" "$pane_id" "$pane_pid"
    ;;
  opencode:idle|opencode:busy)
    state_dir="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
    mkdir -p "$state_dir"
    touch "$state_dir/opencode-busy-${pane_id#%}.ts" 2>/dev/null || true
    tmux select-pane -t "$pane_id" -T opencode:busy >/dev/null 2>&1 || true
    ;;
esac
