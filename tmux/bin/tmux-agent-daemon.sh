#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/agent-state.sh
. "$SCRIPT_DIR/lib/agent-state.sh"

state_dir="$(tmux_agent_ensure_state_dir)"
pid_file="$state_dir/resync-daemon.pid"

if [ -f "$pid_file" ]; then
  old_pid="$(cat "$pid_file" 2> /dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2> /dev/null; then
    exit 0
  fi
fi

echo $$ > "$pid_file"
cleanup() {
  rm -f "$pid_file"
}
trap cleanup EXIT INT TERM

lock_file="$state_dir/resync-daemon.lock"

while true; do
  if ! tmux list-panes > /dev/null 2>&1; then
    break
  fi

  if command -v flock > /dev/null 2>&1; then
    flock -n "$lock_file" "${HOME}/bin/tmux-agent-resync.sh" > /dev/null 2>&1 || true
  else
    "${HOME}/bin/tmux-agent-resync.sh" > /dev/null 2>&1 || true
  fi
  sleep 10
done
