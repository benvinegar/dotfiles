#!/usr/bin/env bash
set -euo pipefail

# Popup-friendly snapshot of all windows in the current tmux session.
# Shows agent type/state from pane title + recent activity age + last prompt/output line.

if ! tmux list-windows > /dev/null 2>&1; then
  echo "Not inside a tmux server/session."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/agent-state.sh
. "$SCRIPT_DIR/lib/agent-state.sh"

STATE_DIR="$(tmux_agent_ensure_state_dir)"
LLM_SUMMARY_FILE="$STATE_DIR/agent-overview-llm-summary.txt"
LLM_SUMMARY_TS_FILE="$STATE_DIR/agent-overview-llm-summary.ts"

trim_text() {
  local text="$1"
  local max_len="${2:-110}"
  text="$(printf '%s' "$text" | tr '\t\r\n' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  if [ "${#text}" -gt "$max_len" ]; then
    printf '%s…' "${text:0:$((max_len - 1))}"
  else
    printf '%s' "$text"
  fi
}

format_age() {
  local sec="${1:-}"
  if [ -z "$sec" ] || ! [[ "$sec" =~ ^[0-9]+$ ]]; then
    printf -- '-'
    return
  fi
  if [ "$sec" -lt 60 ]; then
    printf '%ss' "$sec"
    return
  fi
  if [ "$sec" -lt 3600 ]; then
    printf '%sm' "$((sec / 60))"
    return
  fi
  if [ "$sec" -lt 86400 ]; then
    printf '%sh%sm' "$((sec / 3600))" "$(((sec % 3600) / 60))"
    return
  fi
  printf '%sd%sh' "$((sec / 86400))" "$(((sec % 86400) / 3600))"
}

pane_preview() {
  local pane_id="$1"
  local captured prompt last

  captured="$(tmux capture-pane -pt "$pane_id" -S -120 2> /dev/null || true)"

  # Codex prompt line is usually the most useful “current work” preview.
  prompt="$(printf '%s\n' "$captured" | awk '/^[[:space:]]*› /{last=$0} END{print last}')"
  if [ -n "$prompt" ]; then
    trim_text "$prompt" 120
    return
  fi

  # Fallback: last non-empty line in pane.
  last="$(printf '%s\n' "$captured" | awk 'NF{last=$0} END{print last}')"
  trim_text "$last" 120
}

strip_ansi() {
  sed -E $'s/\x1B\[[0-9;?]*[ -/]*[@-~]//g; s/\x1B[@-_]//g'
}

pane_excerpt() {
  local pane_id="$1"
  local max_lines="${2:-30}"
  local max_chars="${3:-900}"
  local captured cleaned

  captured="$(tmux capture-pane -pt "$pane_id" -S -160 2> /dev/null || true)"
  cleaned="$(printf '%s\n' "$captured" | strip_ansi | tail -n "$max_lines" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  cleaned="$(printf '%s\n' "$cleaned" | awk 'NF')"

  if [ -z "$cleaned" ]; then
    printf '(no visible output)'
    return
  fi

  if [ "${#cleaned}" -gt "$max_chars" ]; then
    printf '%s…' "${cleaned:0:$((max_chars - 1))}"
  else
    printf '%s' "$cleaned"
  fi
}

trigger_pi_recaps() {
  tmux list-panes -F '#{pane_id} #{pane_title}' \
    | while read -r pane_id pane_title; do
      case "$pane_title" in
        pi:*)
          tmux send-keys -t "$pane_id" '/recap raw' Enter > /dev/null 2>&1 || true
          ;;
      esac
    done
}

generate_llm_summaries() {
  local session_name prompt_file output_file
  session_name="$(tmux display-message -p '#S')"
  prompt_file="$(mktemp)"
  output_file="$(mktemp)"

  {
    cat << 'PROMPT'
You are summarizing active tmux agent windows.

Return plain text with exactly one bullet per window in ascending order.
Use this format exactly:
- W<index> <agent>/<state>: <brief summary>

Constraints:
- Keep each summary under 14 words.
- Be concrete and conservative; do not invent unstated progress.
- If unclear, say waiting/idle based on the signals provided.
- Mention blockers briefly if obvious.
PROMPT
    printf '\nSession: %s\n\n' "$session_name"

    while IFS= read -r window_index; do
      [ -n "$window_index" ] || continue

      local target pane_id pane_pid pane_title pane_cmd pane_path
      target="${session_name}:$window_index"

      pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')"
      pane_pid="$(tmux display-message -p -t "$target" '#{pane_pid}')"
      pane_title="$(tmux display-message -p -t "$target" '#{pane_title}')"
      pane_cmd="$(tmux display-message -p -t "$target" '#{pane_current_command}')"
      pane_path="$(tmux display-message -p -t "$target" '#{pane_current_path}')"

      local agent state _codex_node_pid codex_pid pi_pid opencode_pid pids age age_text preview folder excerpt

      case "$pane_title" in
        codex:* | pi:* | opencode:*)
          agent="${pane_title%%:*}"
          state="${pane_title#*:}"
          ;;
        *)
          agent=""
          state="?"
          ;;
      esac

      pids="$(tmux_agent_find_pids "$pane_pid")"
      IFS='|' read -r _codex_node_pid codex_pid pi_pid opencode_pid <<< "$pids"

      if [ -z "$agent" ]; then
        if [ -n "$codex_pid" ]; then
          agent="codex"
        elif [ -n "$pi_pid" ]; then
          agent="pi"
        elif [ -n "$opencode_pid" ]; then
          agent="opencode"
        else
          agent="$pane_cmd"
        fi
      fi

      age=""
      case "$agent" in
        codex)
          age="$(tmux_agent_codex_activity_age "$codex_pid" 2> /dev/null || true)"
          ;;
        pi)
          age="$(tmux_agent_pi_activity_age "$pi_pid" 2> /dev/null || true)"
          ;;
        opencode)
          age="$(tmux_agent_opencode_activity_age "$opencode_pid" 2> /dev/null || true)"
          ;;
      esac
      age_text="$(format_age "$age")"

      preview="$(pane_preview "$pane_id")"
      folder="${pane_path##*/}"
      folder="$(trim_text "$folder" 30)"
      excerpt="$(pane_excerpt "$pane_id" 26 1000)"

      printf '### Window %s\n' "$window_index"
      printf 'agent: %s\n' "$agent"
      printf 'state: %s\n' "$state"
      printf 'folder: %s\n' "$folder"
      printf 'activity: %s\n' "$age_text"
      printf 'preview: %s\n' "$preview"
      printf 'recent:\n%s\n\n' "$excerpt"
    done < <(tmux list-windows -F '#{window_index}')
  } > "$prompt_file"

  if ! command -v codex > /dev/null 2>&1; then
    printf 'LLM summaries unavailable: codex CLI not found.\n' > "$LLM_SUMMARY_FILE"
    date '+%Y-%m-%d %H:%M:%S' > "$LLM_SUMMARY_TS_FILE"
    rm -f "$prompt_file" "$output_file"
    return
  fi

  local log_file
  log_file="$STATE_DIR/agent-overview-llm.log"

  if timeout 120 codex exec --skip-git-repo-check --ephemeral --color never --output-last-message "$output_file" - < "$prompt_file" > "$log_file" 2>&1; then
    if [ -s "$output_file" ]; then
      printf '%s\n' "$(cat "$output_file")" | strip_ansi > "$LLM_SUMMARY_FILE"
      date '+%Y-%m-%d %H:%M:%S' > "$LLM_SUMMARY_TS_FILE"
    else
      printf 'LLM summary returned no output.\n' > "$LLM_SUMMARY_FILE"
      date '+%Y-%m-%d %H:%M:%S' > "$LLM_SUMMARY_TS_FILE"
    fi
  else
    local ec
    ec=$?
    if [ "$ec" -eq 124 ]; then
      printf 'LLM summary timed out after 120s.\n' > "$LLM_SUMMARY_FILE"
    else
      printf 'LLM summary request failed (exit %s).\n' "$ec" > "$LLM_SUMMARY_FILE"
    fi
    if [ -s "$log_file" ]; then
      printf '\nRecent codex exec log:\n' >> "$LLM_SUMMARY_FILE"
      tail -n 6 "$log_file" | strip_ansi >> "$LLM_SUMMARY_FILE"
    fi
    date '+%Y-%m-%d %H:%M:%S' > "$LLM_SUMMARY_TS_FILE"
  fi

  rm -f "$prompt_file" "$output_file"
}

render_once() {
  tmux run-shell "$HOME/bin/tmux-agent-resync.sh" > /dev/null 2>&1 || true

  local session_name
  session_name="$(tmux display-message -p '#S')"

  printf 'Agent overview — session %s — %s\n' "$session_name" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf -- '------------------------------------------------------------------------------------------------------------------------\n'
  printf '%-4s %-9s %-8s %-22s %-7s %s\n' 'Win' 'Agent' 'State' 'Folder' 'Active' 'Preview'
  printf -- '------------------------------------------------------------------------------------------------------------------------\n'

  while IFS= read -r window_index; do
    [ -n "$window_index" ] || continue

    local target window_active pane_id pane_pid pane_title pane_cmd pane_path
    target="${session_name}:$window_index"

    window_active="$(tmux display-message -p -t "$target" '#{window_active}')"
    pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')"
    pane_pid="$(tmux display-message -p -t "$target" '#{pane_pid}')"
    pane_title="$(tmux display-message -p -t "$target" '#{pane_title}')"
    pane_cmd="$(tmux display-message -p -t "$target" '#{pane_current_command}')"
    pane_path="$(tmux display-message -p -t "$target" '#{pane_current_path}')"

    local agent state _codex_node_pid codex_pid pi_pid opencode_pid pids age age_text preview folder win

    case "$pane_title" in
      codex:* | pi:* | opencode:*)
        agent="${pane_title%%:*}"
        state="${pane_title#*:}"
        ;;
      *)
        agent=""
        state="?"
        ;;
    esac

    pids="$(tmux_agent_find_pids "$pane_pid")"
    IFS='|' read -r _codex_node_pid codex_pid pi_pid opencode_pid <<< "$pids"

    if [ -z "$agent" ]; then
      if [ -n "$codex_pid" ]; then
        agent="codex"
      elif [ -n "$pi_pid" ]; then
        agent="pi"
      elif [ -n "$opencode_pid" ]; then
        agent="opencode"
      else
        agent="$pane_cmd"
      fi
    fi

    age=""
    case "$agent" in
      codex)
        age="$(tmux_agent_codex_activity_age "$codex_pid" 2> /dev/null || true)"
        ;;
      pi)
        age="$(tmux_agent_pi_activity_age "$pi_pid" 2> /dev/null || true)"
        ;;
      opencode)
        age="$(tmux_agent_opencode_activity_age "$opencode_pid" 2> /dev/null || true)"
        ;;
    esac
    age_text="$(format_age "$age")"

    preview="$(pane_preview "$pane_id")"
    folder="${pane_path##*/}"
    folder="$(trim_text "$folder" 22)"

    if [ "$window_active" = "1" ]; then
      win="${window_index}*"
    else
      win="$window_index"
    fi

    printf '%-4s %-9s %-8s %-22s %-7s %s\n' "$win" "$agent" "$state" "$folder" "$age_text" "$preview"
  done < <(tmux list-windows -F '#{window_index}')

  if [ -s "$LLM_SUMMARY_FILE" ]; then
    local summary_ts
    summary_ts="$(cat "$LLM_SUMMARY_TS_FILE" 2> /dev/null || echo "unknown")"
    printf '\nLLM summaries (%s)\n' "$summary_ts"
    printf -- '------------------------------------------------------------------------------------------------------------------------\n'
    sed -n '1,12p' "$LLM_SUMMARY_FILE"
  fi

  printf '\nKeys: r refresh · s generate LLM summaries · a run /recap raw on pi panes · q close · 0-9 jump to window\n'
}

while true; do
  clear
  render_once

  while IFS= read -rsn1 key; do
    case "$key" in
      q | Q)
        exit 0
        ;;
      r | R)
        break
        ;;
      a | A)
        trigger_pi_recaps
        sleep 0.2
        break
        ;;
      s | S)
        clear
        printf 'Generating LLM summaries for all windows...\n'
        generate_llm_summaries
        break
        ;;
      [0-9])
        tmux select-window -t "$key" > /dev/null 2>&1 || true
        exit 0
        ;;
      *)
        # Ignore unknown keys without forcing a redraw.
        continue
        ;;
    esac
  done
done
