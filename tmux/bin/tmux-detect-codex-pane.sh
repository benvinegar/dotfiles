#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
pane_pid="${2:-}"
pane_title="${3:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/agent-state.sh
. "$SCRIPT_DIR/lib/agent-state.sh"

[ -n "$pane_id" ] || exit 0
[ -n "$pane_pid" ] || exit 0

has_codex=0
has_pi=0
has_opencode=0
codex_node_pid=""
codex_pid=""
pi_pid=""
opencode_pid=""

pids="$(tmux_agent_find_pids "$pane_pid")"
IFS='|' read -r codex_node_pid codex_pid pi_pid opencode_pid <<< "$pids"

[ -n "$codex_node_pid" ] && has_codex=1
[ -n "$pi_pid" ] && has_pi=1
[ -n "$opencode_pid" ] && has_opencode=1

pi_watch_pid_file="$(tmux_agent_pi_watch_pid_file "$pane_id")"
codex_busy_stamp_file="$(tmux_agent_busy_stamp_file codex "$pane_id")"
opencode_busy_stamp_file="$(tmux_agent_busy_stamp_file opencode "$pane_id")"

# Fallback: clear stale "busy" if there is no observable activity for this long.
codex_busy_stale_sec=35
pi_busy_stale_sec=40

set_title() {
  tmux_agent_set_title "$pane_id" "$1"
}

pi_watch_running() {
  local watch_pid
  [ -f "$pi_watch_pid_file" ] || return 1
  watch_pid="$(cat "$pi_watch_pid_file" 2> /dev/null || true)"
  [ -n "$watch_pid" ] || return 1
  kill -0 "$watch_pid" 2> /dev/null
}

codex_busy_recent() {
  # Grace window right after Enter while a turn spins up.
  tmux_agent_file_recent "$codex_busy_stamp_file" 25
}

codex_recently_active() {
  local age
  age="$(tmux_agent_codex_activity_age "$1" 2> /dev/null || true)"
  [ -n "$age" ] || return 1
  [ "$age" -le 20 ]
}

opencode_busy_recent() {
  # Keep busy briefly after Enter until first log write arrives.
  tmux_agent_file_recent "$opencode_busy_stamp_file" 10
}

opencode_recently_active() {
  local age
  age="$(tmux_agent_opencode_activity_age "$1" 2> /dev/null || true)"
  [ -n "$age" ] || return 1
  [ "$age" -le 12 ]
}

pi_recently_active() {
  local age
  age="$(tmux_agent_pi_activity_age "$1" 2> /dev/null || true)"
  [ -n "$age" ] || return 1
  [ "$age" -le 10 ]
}

if [ "$has_codex" -eq 1 ]; then
  if [ "$pane_title" = "codex:busy" ]; then
    codex_age="$(tmux_agent_codex_activity_age "$codex_pid" 2> /dev/null || true)"
    # Prefer explicit busy from Enter; keep busy while session activity is recent,
    # then fail-safe back to idle if activity stays stale.
    if codex_busy_recent || { [ -n "$codex_age" ] && [ "$codex_age" -le "$codex_busy_stale_sec" ]; }; then
      desired_codex_title="codex:busy"
    else
      desired_codex_title="codex:idle"
      rm -f "$codex_busy_stamp_file" 2> /dev/null || true
    fi
  else
    # Conservative: only Enter grace can promote idle -> busy.
    if codex_busy_recent; then
      desired_codex_title="codex:busy"
    else
      desired_codex_title="codex:idle"
      rm -f "$codex_busy_stamp_file" 2> /dev/null || true
    fi
  fi
else
  desired_codex_title="codex:offline"
  rm -f "$codex_busy_stamp_file" 2> /dev/null || true
fi

if [ "$has_pi" -eq 1 ]; then
  # Conservative default: rely on explicit busy signals (extension/watcher).
  desired_pi_title="pi:idle"
else
  desired_pi_title="pi:offline"
fi

if [ "$has_opencode" -eq 1 ]; then
  if opencode_recently_active "$opencode_pid" || opencode_busy_recent; then
    desired_opencode_title="opencode:busy"
  else
    desired_opencode_title="opencode:idle"
    rm -f "$opencode_busy_stamp_file" 2> /dev/null || true
  fi
else
  desired_opencode_title="opencode:offline"
  rm -f "$opencode_busy_stamp_file" 2> /dev/null || true
fi

case "$pane_title" in
  codex:*)
    if [ "$pane_title" != "$desired_codex_title" ]; then
      set_title "$desired_codex_title"
    fi
    ;;
  pi:*)
    if [ "$pane_title" = "pi:busy" ] && [ "$has_pi" -eq 1 ]; then
      pi_age="$(tmux_agent_pi_activity_age "$pi_pid" 2> /dev/null || true)"
      # Prefer explicit busy state, but clear stale busy after inactivity.
      if pi_watch_running || pi_recently_active "$pi_pid" || { [ -n "$pi_age" ] && [ "$pi_age" -le "$pi_busy_stale_sec" ]; }; then
        :
      else
        set_title pi:idle
      fi
    elif [ "$pane_title" != "$desired_pi_title" ]; then
      set_title "$desired_pi_title"
    fi
    ;;
  opencode:*)
    if [ "$pane_title" != "$desired_opencode_title" ]; then
      set_title "$desired_opencode_title"
    fi
    ;;
  *)
    if [ "$has_codex" -eq 1 ]; then
      set_title "$desired_codex_title"
    elif [ "$has_pi" -eq 1 ]; then
      set_title "$desired_pi_title"
    elif [ "$has_opencode" -eq 1 ]; then
      set_title "$desired_opencode_title"
    fi
    ;;
esac
