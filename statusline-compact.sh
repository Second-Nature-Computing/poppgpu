#!/bin/bash
# claude-gpu-statusline (compact) — single-line GPU monitoring for Claude Code
# Shows Claude session info + key GPU metrics on one line
#
# Requirements: jq, nvidia-smi
# Install: See README.md

input=$(cat)

# Parse Claude Code session data
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# GPU metrics
GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
GPU_POWER=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | tr -d ' ' | cut -d. -f1)

# System memory
MEM_USED=$(free -g 2>/dev/null | awk '/Mem:/{print $3}')
MEM_TOTAL=$(free -g 2>/dev/null | awk '/Mem:/{print $2}')

# Top GPU process
TOP_PROC=$(nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader 2>/dev/null | head -1)
if [ -n "$TOP_PROC" ]; then
    PROC_NAME=$(echo "$TOP_PROC" | cut -d',' -f1 | xargs basename 2>/dev/null)
    PROC_MEM=$(echo "$TOP_PROC" | cut -d',' -f2 | tr -d ' ')
fi

# Colors
RED='\033[31m'
GRN='\033[32m'
YEL='\033[33m'
MAG='\033[35m'
DIM='\033[2m'
RST='\033[0m'
BOLD='\033[1m'

# Color helpers
color_by_pct() {
    local val=${1:-0}
    if [ "$val" -ge 80 ]; then echo -ne "$RED"
    elif [ "$val" -ge 50 ]; then echo -ne "$YEL"
    else echo -ne "$GRN"; fi
}

# Bar graph (8 chars)
bar() {
    local pct=${1:-0}
    local w=8 filled=$((pct * 8 / 100)) empty
    empty=$((w - filled))
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
}

# Build output
printf "${BOLD}${MAG}%s${RST}" "$MODEL"
printf " ${DIM}│${RST} "
printf "ctx $(color_by_pct "$PCT")$(bar "$PCT") ${PCT}%%${RST}"
printf " ${DIM}│${RST} "
printf "${DIM}\$${RST}$(printf '%.2f' "$COST")"
printf " ${DIM}│${RST} "
printf "⚡$(color_by_pct "${GPU_UTIL:-0}")$(bar "${GPU_UTIL:-0}") ${GPU_UTIL:-?}%%${RST}"
printf " $(color_by_pct "${GPU_TEMP:-0}")${GPU_TEMP:-?}°C${RST}"
printf " ${DIM}${GPU_POWER:-?}W${RST}"
printf " ${DIM}${MEM_USED:-?}/${MEM_TOTAL:-?}G${RST}"
if [ -n "$PROC_NAME" ]; then
    printf " ${DIM}│ ${PROC_NAME} ${PROC_MEM}${RST}"
fi
printf "\n"
