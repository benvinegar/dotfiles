#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
pid_file="$state_dir/resync-daemon.pid"
mkdir -p "$state_dir"

if [ -f "$pid_file" ]; then
  old_pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi

echo $$ > "$pid_file"
cleanup() {
  rm -f "$pid_file"
}
trap cleanup EXIT INT TERM

while true; do
  if ! tmux list-panes >/dev/null 2>&1; then
    break
  fi

  "${HOME}/bin/tmux-agent-resync.sh" >/dev/null 2>&1 || true
  sleep 2
done
