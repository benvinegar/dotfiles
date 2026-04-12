#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
pane_pid="${2:-}"
pane_title="${3:-}"

[ -n "$pane_id" ] || exit 0
[ -n "$pane_pid" ] || exit 0

children="$(pgrep -a -P "$pane_pid" 2> /dev/null || true)"

has_codex=0
has_pi=0
has_opencode=0
codex_node_pid=""
codex_pid=""
pi_pid=""
opencode_pid=""

if [ -n "$children" ]; then
  # npm-installed Codex typically appears as: node .../bin/codex ...
  codex_node_pid="$(printf '%s\n' "$children" | awk '$2=="node" && $0 ~ /(^|[[:space:]])codex([[:space:]]|$)|\/bin\/codex/ { print $1; exit }')"
  if [ -n "$codex_node_pid" ]; then
    has_codex=1
    codex_pid="$(pgrep -P "$codex_node_pid" -x codex 2> /dev/null | head -n 1 || true)"
  fi

  # pi process is typically a direct child named `pi`
  if printf '%s\n' "$children" | awk '$2=="pi" { found=1 } END { exit(found?0:1) }'; then
    has_pi=1
    pi_pid="$(printf '%s\n' "$children" | awk '$2=="pi" { print $1; exit }')"
  fi

  # OpenCode process (direct child named `opencode`)
  if printf '%s\n' "$children" | awk '$2=="opencode" { found=1 } END { exit(found?0:1) }'; then
    has_opencode=1
    opencode_pid="$(printf '%s\n' "$children" | awk '$2=="opencode" { print $1; exit }')"
  fi
fi

state_dir="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
pi_watch_pid_file="$state_dir/pi-watch-${pane_id#%}.pid"
codex_busy_stamp_file="$state_dir/codex-busy-${pane_id#%}.ts"
opencode_busy_stamp_file="$state_dir/opencode-busy-${pane_id#%}.ts"

# Fallback: clear stale "busy" if there is no observable activity for this long.
codex_busy_stale_sec=35
pi_busy_stale_sec=40

set_title() {
  tmux select-pane -t "$pane_id" -T "$1" > /dev/null 2>&1 || true
}

pi_watch_running() {
  local watch_pid
  [ -f "$pi_watch_pid_file" ] || return 1
  watch_pid="$(cat "$pi_watch_pid_file" 2> /dev/null || true)"
  [ -n "$watch_pid" ] || return 1
  kill -0 "$watch_pid" 2> /dev/null
}

codex_busy_recent() {
  local now mtime
  [ -f "$codex_busy_stamp_file" ] || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$codex_busy_stamp_file" 2> /dev/null || echo 0)"
  # Grace window right after Enter while a turn spins up.
  [ $((now - mtime)) -le 25 ]
}

codex_activity_age() {
  local pid="$1"
  local session_file now mtime

  [ -n "$pid" ] || return 1

  session_file="$(lsof -Fn -p "$pid" 2> /dev/null | sed -n 's/^n//p' | sed 's/ (deleted)$//' | grep '/\.codex/sessions/.*\.jsonl$' | head -n 1 || true)"
  [ -n "$session_file" ] || return 1
  [ -f "$session_file" ] || return 1

  now="$(date +%s)"
  mtime="$(stat -c %Y "$session_file" 2> /dev/null || echo 0)"
  printf '%s\n' "$((now - mtime))"
}

codex_recently_active() {
  local age
  age="$(codex_activity_age "$1" 2> /dev/null || true)"
  [ -n "$age" ] || return 1
  [ "$age" -le 20 ]
}

opencode_busy_recent() {
  local now mtime
  [ -f "$opencode_busy_stamp_file" ] || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$opencode_busy_stamp_file" 2> /dev/null || echo 0)"
  # Keep busy briefly after Enter until first log write arrives.
  [ $((now - mtime)) -le 10 ]
}

opencode_recently_active() {
  local pid="$1"
  local log_file now mtime

  [ -n "$pid" ] || return 1

  log_file="$(lsof -Fn -p "$pid" 2> /dev/null | sed -n 's/^n//p' | sed 's/ (deleted)$//' | grep '/\.local/share/opencode/log/.*\.log$' | head -n 1 || true)"

  # Fallback: newest known OpenCode log file.
  if [ -z "$log_file" ]; then
    log_file="$(ls -1t "$HOME"/.local/share/opencode/log/*.log 2> /dev/null | head -n 1 || true)"
  fi

  [ -n "$log_file" ] || return 1
  [ -f "$log_file" ] || return 1

  now="$(date +%s)"
  mtime="$(stat -c %Y "$log_file" 2> /dev/null || echo 0)"
  [ $((now - mtime)) -le 12 ]
}

pi_activity_age() {
  local pid="$1"
  local session_file now mtime cwd session_key session_dir

  [ -n "$pid" ] || return 1

  session_file="$(lsof -Fn -p "$pid" 2> /dev/null | sed -n 's/^n//p' | grep '/\.pi/agent/sessions/.*\.jsonl$' | head -n 1 || true)"

  # Fallback: derive session directory from pi process cwd and pick newest session.
  if [ -z "$session_file" ]; then
    cwd="$(readlink -f "/proc/$pid/cwd" 2> /dev/null || true)"
    if [ -n "$cwd" ]; then
      session_key="--${cwd#/}--"
      session_key="${session_key//\//-}"
      session_dir="$HOME/.pi/agent/sessions/$session_key"
      session_file="$(ls -1t "$session_dir"/*.jsonl 2> /dev/null | head -n 1 || true)"
    fi
  fi

  [ -n "$session_file" ] || return 1
  [ -f "$session_file" ] || return 1

  now="$(date +%s)"
  mtime="$(stat -c %Y "$session_file" 2> /dev/null || echo 0)"
  printf '%s\n' "$((now - mtime))"
}

pi_recently_active() {
  local age
  age="$(pi_activity_age "$1" 2> /dev/null || true)"
  [ -n "$age" ] || return 1
  [ "$age" -le 10 ]
}

if [ "$has_codex" -eq 1 ]; then
  if [ "$pane_title" = "codex:busy" ]; then
    codex_age="$(codex_activity_age "$codex_pid" 2> /dev/null || true)"
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
      pi_age="$(pi_activity_age "$pi_pid" 2> /dev/null || true)"
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
