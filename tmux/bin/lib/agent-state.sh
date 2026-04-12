#!/usr/bin/env bash

tmux_agent_state_dir() {
  printf '%s\n' "${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
}

tmux_agent_ensure_state_dir() {
  local dir
  dir="$(tmux_agent_state_dir)"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

tmux_agent_pane_key() {
  printf '%s\n' "${1#%}"
}

tmux_agent_busy_stamp_file() {
  local agent="$1"
  local pane_id="$2"

  printf '%s/%s-busy-%s.ts\n' "$(tmux_agent_state_dir)" "$agent" "$(tmux_agent_pane_key "$pane_id")"
}

tmux_agent_pi_watch_pid_file() {
  local pane_id="$1"

  printf '%s/pi-watch-%s.pid\n' "$(tmux_agent_state_dir)" "$(tmux_agent_pane_key "$pane_id")"
}

tmux_agent_set_title() {
  local pane_id="$1"
  local title="$2"

  tmux select-pane -t "$pane_id" -T "$title" > /dev/null 2>&1 || true
}

tmux_agent_file_mtime() {
  stat -c %Y "$1" 2> /dev/null || stat -f %m "$1" 2> /dev/null || echo 0
}

tmux_agent_file_age() {
  local file="$1"
  local now mtime

  [ -n "$file" ] || return 1
  [ -f "$file" ] || return 1

  now="$(date +%s)"
  mtime="$(tmux_agent_file_mtime "$file")"
  printf '%s\n' "$((now - mtime))"
}

tmux_agent_file_recent() {
  local file="$1"
  local max_age="$2"
  local age

  age="$(tmux_agent_file_age "$file" 2> /dev/null || true)"
  [ -n "$age" ] || return 1
  [ "$age" -le "$max_age" ]
}

tmux_agent_newest_file() {
  local dir="$1"
  local pattern="$2"
  local file newest newest_mtime mtime had_nullglob

  [ -d "$dir" ] || return 1

  had_nullglob=0
  shopt -q nullglob && had_nullglob=1
  shopt -s nullglob

  newest=""
  newest_mtime=0
  for file in "$dir"/$pattern; do
    [ -f "$file" ] || continue
    mtime="$(tmux_agent_file_mtime "$file")"
    if [ -z "$newest" ] || [ "$mtime" -gt "$newest_mtime" ]; then
      newest="$file"
      newest_mtime="$mtime"
    fi
  done

  if [ "$had_nullglob" -eq 0 ]; then
    shopt -u nullglob
  fi

  [ -n "$newest" ] || return 1
  printf '%s\n' "$newest"
}

tmux_agent_find_pids() {
  local pane_pid="$1"
  local children codex_node_pid codex_pid pi_pid opencode_pid

  children="$(pgrep -a -P "$pane_pid" 2> /dev/null || true)"
  codex_node_pid=""
  codex_pid=""
  pi_pid=""
  opencode_pid=""

  if [ -n "$children" ]; then
    codex_node_pid="$(printf '%s\n' "$children" | awk '$2=="node" && $0 ~ /(^|[[:space:]])codex([[:space:]]|$)|\/bin\/codex/ { print $1; exit }')"
    if [ -n "$codex_node_pid" ]; then
      codex_pid="$(pgrep -P "$codex_node_pid" -x codex 2> /dev/null | head -n 1 || true)"
    fi

    pi_pid="$(printf '%s\n' "$children" | awk '$2=="pi" { print $1; exit }')"
    opencode_pid="$(printf '%s\n' "$children" | awk '$2=="opencode" { print $1; exit }')"
  fi

  printf '%s|%s|%s|%s\n' "$codex_node_pid" "$codex_pid" "$pi_pid" "$opencode_pid"
}

tmux_agent_codex_session_file() {
  local pid="$1"
  local session_file

  [ -n "$pid" ] || return 1

  session_file="$(lsof -Fn -p "$pid" 2> /dev/null | sed -n 's/^n//p' | sed 's/ (deleted)$//' | grep '/\.codex/sessions/.*\.jsonl$' | head -n 1 || true)"
  [ -n "$session_file" ] || return 1
  [ -f "$session_file" ] || return 1

  printf '%s\n' "$session_file"
}

tmux_agent_pi_session_dir() {
  local pid="$1"
  local cwd session_key

  [ -n "$pid" ] || return 1

  cwd="$(readlink -f "/proc/$pid/cwd" 2> /dev/null || true)"
  [ -n "$cwd" ] || return 1

  session_key="--${cwd#/}--"
  session_key="${session_key//\//-}"
  printf '%s\n' "$HOME/.pi/agent/sessions/$session_key"
}

tmux_agent_pi_session_file() {
  local pid="$1"
  local session_file session_dir

  [ -n "$pid" ] || return 1

  session_file="$(lsof -Fn -p "$pid" 2> /dev/null | sed -n 's/^n//p' | grep '/\.pi/agent/sessions/.*\.jsonl$' | head -n 1 || true)"

  if [ -z "$session_file" ]; then
    session_dir="$(tmux_agent_pi_session_dir "$pid" 2> /dev/null || true)"
    if [ -n "$session_dir" ]; then
      session_file="$(tmux_agent_newest_file "$session_dir" '*.jsonl' 2> /dev/null || true)"
    fi
  fi

  [ -n "$session_file" ] || return 1
  [ -f "$session_file" ] || return 1

  printf '%s\n' "$session_file"
}

tmux_agent_opencode_log_file() {
  local pid="$1"
  local log_file

  [ -n "$pid" ] || return 1

  log_file="$(lsof -Fn -p "$pid" 2> /dev/null | sed -n 's/^n//p' | sed 's/ (deleted)$//' | grep '/\.local/share/opencode/log/.*\.log$' | head -n 1 || true)"
  if [ -z "$log_file" ]; then
    log_file="$(tmux_agent_newest_file "$HOME/.local/share/opencode/log" '*.log' 2> /dev/null || true)"
  fi

  [ -n "$log_file" ] || return 1
  [ -f "$log_file" ] || return 1

  printf '%s\n' "$log_file"
}

tmux_agent_codex_activity_age() {
  local session_file

  session_file="$(tmux_agent_codex_session_file "$1" 2> /dev/null || true)"
  [ -n "$session_file" ] || return 1

  tmux_agent_file_age "$session_file"
}

tmux_agent_pi_activity_age() {
  local session_file

  session_file="$(tmux_agent_pi_session_file "$1" 2> /dev/null || true)"
  [ -n "$session_file" ] || return 1

  tmux_agent_file_age "$session_file"
}

tmux_agent_opencode_activity_age() {
  local log_file

  log_file="$(tmux_agent_opencode_log_file "$1" 2> /dev/null || true)"
  [ -n "$log_file" ] || return 1

  tmux_agent_file_age "$log_file"
}
