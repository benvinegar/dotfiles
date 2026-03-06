#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
pane_pid="${2:-}"

[ -n "$pane_id" ] || exit 0
[ -n "$pane_pid" ] || exit 0

pi_pid="$(pgrep -P "$pane_pid" -x pi 2>/dev/null | head -n 1 || true)"
[ -n "$pi_pid" ] || exit 0

session_file="$(lsof -Fn -p "$pi_pid" 2>/dev/null | sed -n 's/^n//p' | grep '/\.pi/agent/sessions/.*\.jsonl$' | head -n 1 || true)"

# Fallback: derive session directory from pi process cwd and pick newest session.
if [ -z "$session_file" ]; then
  cwd="$(readlink -f "/proc/$pi_pid/cwd" 2>/dev/null || true)"
  if [ -n "$cwd" ]; then
    session_key="--${cwd#/}--"
    session_key="${session_key//\//-}"
    session_dir="$HOME/.pi/agent/sessions/$session_key"
    session_file="$(ls -1t "$session_dir"/*.jsonl 2>/dev/null | head -n 1 || true)"
  fi
fi

[ -n "$session_file" ] || exit 0
[ -f "$session_file" ] || exit 0

state_dir="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
mkdir -p "$state_dir"
watch_key="${pane_id#%}"
pid_file="$state_dir/pi-watch-${watch_key}.pid"

# Replace any existing watcher for this pane.
if [ -f "$pid_file" ]; then
  old_pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    kill "$old_pid" 2>/dev/null || true
  fi
fi

(
  echo $$ > "$pid_file"

  tmux select-pane -t "$pane_id" -T pi:busy >/dev/null 2>&1 || true

  stable_seconds=0
  saw_change=0
  started_at="$(date +%s)"
  last_mtime="$(stat -c %Y "$session_file" 2>/dev/null || echo 0)"

  while kill -0 "$pi_pid" 2>/dev/null; do
    sleep 1

    current_mtime="$(stat -c %Y "$session_file" 2>/dev/null || echo 0)"
    if [ "$current_mtime" != "$last_mtime" ]; then
      saw_change=1
      stable_seconds=0
      last_mtime="$current_mtime"
      tmux select-pane -t "$pane_id" -T pi:busy >/dev/null 2>&1 || true
      continue
    fi

    stable_seconds=$((stable_seconds + 1))

    elapsed=$(( $(date +%s) - started_at ))

    # Normal completion path: once we observe session log activity and then it
    # goes quiet for a few seconds, treat the turn as complete.
    if [ "$saw_change" -eq 1 ] && [ "$stable_seconds" -ge 3 ]; then
      tmux select-pane -t "$pane_id" -T pi:idle >/dev/null 2>&1 || true
      break
    fi

    # Fallback: if we never observed session-log writes, keep busy for a while
    # (models can spend time thinking before first write), then fail open.
    if [ "$saw_change" -eq 0 ] && [ "$elapsed" -ge 90 ]; then
      tmux select-pane -t "$pane_id" -T pi:idle >/dev/null 2>&1 || true
      break
    fi

    # Hard stop after 20 minutes to avoid stale watchers.
    if [ "$elapsed" -ge 1200 ]; then
      tmux select-pane -t "$pane_id" -T pi:idle >/dev/null 2>&1 || true
      break
    fi
  done

  rm -f "$pid_file"
) >/dev/null 2>&1 &
