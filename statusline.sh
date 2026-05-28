#!/bin/bash
# claude-gpu-statusline — GPU monitoring for Claude Code
# Shows Claude session info + full nvitop output in the statusline
#
# Requirements: nvitop, jq, nvidia-smi
# Install: See README.md

input=$(cat)

# Parse Claude Code session data
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Colors
RED='\033[31m'
GRN='\033[32m'
YEL='\033[33m'
MAG='\033[35m'
DIM='\033[2m'
RST='\033[0m'
BOLD='\033[1m'

# Context color
if [ "${PCT:-0}" -ge 80 ]; then
    CTX_CLR=$RED
elif [ "${PCT:-0}" -ge 50 ]; then
    CTX_CLR=$YEL
else
    CTX_CLR=$GRN
fi

# Line 1: Claude session info
printf "${BOLD}${MAG}%s${RST} ${DIM}│${RST} ctx ${CTX_CLR}%s%%${RST} ${DIM}│${RST} ${DIM}\$${RST}%s\n" \
    "$MODEL" "$PCT" "$(printf '%.2f' "$COST")"

# Lines 2+: Full nvitop colorful output (skip timestamp line)
nvitop --colorful -1 2>/dev/null | tail -n +2
