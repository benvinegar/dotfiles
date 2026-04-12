#!/usr/bin/env bash
set -euo pipefail

# Lightweight spinner frame for tmux status updates.
# Called every status refresh (~1s) when an agent is busy.
frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
now="$(date +%s)"
idx=$((now % ${#frames[@]}))
printf '%s' "${frames[$idx]}"
