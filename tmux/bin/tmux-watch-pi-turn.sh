#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
pane_pid="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# install.sh links tmux helper libs into ~/bin/lib for all tmux scripts.
# Exit quietly if the install step hasn't been rerun yet.
[ -f "$HOME/bin/lib/agent-state.sh" ] || exit 0

# shellcheck source=lib/agent-state.sh
. "$HOME/bin/lib/agent-state.sh"

[ -n "$pane_id" ] || exit 0
[ -n "$pane_pid" ] || exit 0

pi_pid="$(pgrep -P "$pane_pid" -x pi 2> /dev/null | head -n 1 || true)"
[ -n "$pi_pid" ] || exit 0

session_file="$(tmux_agent_pi_session_file "$pi_pid" 2> /dev/null || true)"
[ -n "$session_file" ] || exit 0
[ -f "$session_file" ] || exit 0

tmux_agent_ensure_state_dir > /dev/null
pid_file="$(tmux_agent_pi_watch_pid_file "$pane_id")"

# Replace any existing watcher for this pane.
if [ -f "$pid_file" ]; then
  old_pid="$(cat "$pid_file" 2> /dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2> /dev/null; then
    kill "$old_pid" 2> /dev/null || true
  fi
fi

(
  echo $$ > "$pid_file"

  tmux_agent_set_title "$pane_id" pi:busy

  stable_seconds=0
  saw_change=0
  started_at="$(date +%s)"
  last_mtime="$(tmux_agent_file_mtime "$session_file")"

  while kill -0 "$pi_pid" 2> /dev/null; do
    sleep 1

    current_mtime="$(tmux_agent_file_mtime "$session_file")"
    if [ "$current_mtime" != "$last_mtime" ]; then
      saw_change=1
      stable_seconds=0
      last_mtime="$current_mtime"
      tmux_agent_set_title "$pane_id" pi:busy
      continue
    fi

    stable_seconds=$((stable_seconds + 1))

    elapsed=$(($(date +%s) - started_at))

    # Normal completion path: once we observe session log activity and then it
    # goes quiet for a few seconds, treat the turn as complete.
    if [ "$saw_change" -eq 1 ] && [ "$stable_seconds" -ge 3 ]; then
      tmux_agent_set_title "$pane_id" pi:idle
      break
    fi

    # Fallback: if we never observed session-log writes, keep busy for a while
    # (models can spend time thinking before first write), then fail open.
    if [ "$saw_change" -eq 0 ] && [ "$elapsed" -ge 90 ]; then
      tmux_agent_set_title "$pane_id" pi:idle
      break
    fi

    # Hard stop after 20 minutes to avoid stale watchers.
    if [ "$elapsed" -ge 1200 ]; then
      tmux_agent_set_title "$pane_id" pi:idle
      break
    fi
  done

  rm -f "$pid_file"
) > /dev/null 2>&1 &
