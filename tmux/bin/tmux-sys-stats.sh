#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
mkdir -p "$state_dir"
cpu_state_file="$state_dir/tmux-cpu-prev"

# --- CPU (delta between invocations) ---
read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
idle_all=$((idle + iowait))
non_idle=$((user + nice + system + irq + softirq + steal))
total=$((idle_all + non_idle))

if [ -f "$cpu_state_file" ]; then
  read -r prev_total prev_idle < "$cpu_state_file" || true
else
  prev_total=$total
  prev_idle=$idle_all
fi

printf '%s %s\n' "$total" "$idle_all" > "$cpu_state_file"

total_delta=$((total - prev_total))
idle_delta=$((idle_all - prev_idle))
if [ "$total_delta" -gt 0 ]; then
  cpu_pct=$(( (1000 * (total_delta - idle_delta) / total_delta + 5) / 10 ))
else
  cpu_pct=0
fi

# --- Memory ---
mem_total_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
mem_available_kb=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
mem_used_kb=$((mem_total_kb - mem_available_kb))
mem_pct=$(( (100 * mem_used_kb + mem_total_kb / 2) / mem_total_kb ))

mem_used_gib=$(awk -v kb="$mem_used_kb" 'BEGIN { printf "%.1f", kb/1048576 }')
mem_total_gib=$(awk -v kb="$mem_total_kb" 'BEGIN { printf "%.1f", kb/1048576 }')

# --- Load average ---
read -r load1 load5 load15 _ < /proc/loadavg

# --- Disk usage (root filesystem) ---
disk_pct=$(df -P / | awk 'NR==2 { gsub(/%/, "", $5); print $5 }')

# --- Uptime ---
up_secs=$(awk '{print int($1)}' /proc/uptime)
up_days=$((up_secs / 86400))
up_hours=$(( (up_secs % 86400) / 3600 ))
up_mins=$(( (up_secs % 3600) / 60 ))

if [ "$up_days" -gt 0 ]; then
  uptime_text="${up_days}d${up_hours}h"
elif [ "$up_hours" -gt 0 ]; then
  uptime_text="${up_hours}h${up_mins}m"
else
  uptime_text="${up_mins}m"
fi

printf '󰍛 CPU %s%%   󰘚 MEM %s%% (%s/%s GiB)   󰓅 LOAD %s %s %s   󰋊 DISK %s%%   󰔛 UP %s' \
  "$cpu_pct" "$mem_pct" "$mem_used_gib" "$mem_total_gib" "$load1" "$load5" "$load15" "$disk_pct" "$uptime_text"
