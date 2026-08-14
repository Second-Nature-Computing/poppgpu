#!/bin/bash
# PoppAI — your terminal flower for Claude Code
# A statusline pet that reacts to GPU, system, and Claude session state.
# Repo: https://github.com/Second-Nature-Computing/poppai
# License: MIT
#
# Trigger actions by writing to ~/.claude/poppai_action:
#   echo pet    > ~/.claude/poppai_action   # +pet count, brief affection
#   echo feed   > ~/.claude/poppai_action   # photosynthesis (strain -1 for 10m)
#   echo dance  > ~/.claude/poppai_action   # sway animation
#   echo status > ~/.claude/poppai_action   # profile card with achievements
#
# Everything below is yours to tweak. The CONFIG block has thresholds,
# colors, and the achievement list. Flower art lives in the FLOWER ART
# and ACHIEVEMENT ART sections — change a state, add a state, recolor
# Poppy, the script's structured for it.


# ─────────────────────────────────────────────────────────────────────
# CONFIG  (everything customizable lives here)
# ─────────────────────────────────────────────────────────────────────

# State directory
POPPAI_DIR="$HOME/.claude"

# ── Energy thresholds (positive: GPU/CPU activity) ──────────────────
ENERGY_GPU_BLAZING=90   # → energy 4
ENERGY_GPU_THRIVING=60  # → energy 3
ENERGY_GPU_WORKING=30   # → energy 2
ENERGY_GPU_ALIVE=5      # → energy 1
ENERGY_CPU_BUSY=50      # CPU% alone bumps energy to 2
ENERGY_CPU_PRESENT=30   # CPU% alone bumps energy to 1

# ── Strain thresholds (negative: resource pressure) ─────────────────
STRAIN_TEMP_CRIT=85
STRAIN_TEMP_HIGH=75
STRAIN_RAM_CRIT=95
STRAIN_RAM_HIGH=85
STRAIN_RAM_MED=75
STRAIN_CACHE_CRIT=80    # DGX Spark drop_caches threshold
STRAIN_CACHE_HIGH=65
STRAIN_CACHE_MED=50
STRAIN_CTX_CRIT=90
STRAIN_CTX_HIGH=75
STRAIN_CTX_MED=60
STRAIN_RATE_HIGH=85
STRAIN_RATE_MED=65

# ── Pet/feed effects ────────────────────────────────────────────────
PET_BONUS_SECONDS=300    # 5 min of strain relief after a pet
FEED_BONUS_SECONDS=600   # 10 min of strain relief after a feed

# ── Status-bar scales ───────────────────────────────────────────────
UPT_BAR_DAYS=14          # uptime bar reaches full at this many days
                         # (matches the marathon achievement: 7d = half)

# ── Achievements ────────────────────────────────────────────────────
ACH_DISPLAY_SECONDS=30   # how long an achievement keeps Poppy's special art
ACH_LEET_COST="13.37"    # session cost that triggers the leet achievement
ACH_BIGJOB_MIB=71680     # 70 GiB GPU memory → bigjob
ACH_TINYFILES_PCT=80     # inode % on / → tinyfiles
ACH_MARATHON_SECONDS=604800   # 7 days uptime → marathon
ACH_NEEDY_PETS=10        # pet count → needy

# Achievement registry — `name:description`. Each entry needs:
#   (1) detection (in ACHIEVEMENT DETECTION block)
#   (2) art (in ACHIEVEMENT ART OVERRIDES block; falls back to current state)
# Add yours here and in those two places.
ALL_ACHIEVEMENTS=(
    "nice:GPU hit 69C"
    "zen:All stats green"
    "edge:Context over 95%"
    "nightowl:Working past midnight"
    "weekend:Friday evening or weekend"
    "leet:Cost at \$13.37"
    "fourtwenty:4:20 PM"
    "jobdone:GPU finished big job"
    "chonk:Page cache hit drop_caches level"
    "drained:Flushed page cache 50%+ → ≤10%"
    "marathon:Uptime hit 7 days"
    "bigjob:GPU memory 70GB+ in use"
    "balanced:GPU and CPU both around 50%"
    "throttle:GPU pinned at 100%"
    "needy:Petted 10+ times"
    "tinyfiles:Inode usage on / hit 80%"
)

# ── Colors (xterm 256 — change to match your terminal theme) ────────
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

# Rainbow gradient used by the bars (red → orange → yellow → green →
# cyan → blue → violet). 24 stops; bars sample evenly across.
RAINBOW=('\033[38;5;196m' '\033[38;5;202m' '\033[38;5;208m' '\033[38;5;214m'
         '\033[38;5;220m' '\033[38;5;226m' '\033[38;5;190m' '\033[38;5;154m'
         '\033[38;5;118m' '\033[38;5;82m'  '\033[38;5;46m'  '\033[38;5;47m'
         '\033[38;5;48m'  '\033[38;5;49m'  '\033[38;5;50m'  '\033[38;5;51m'
         '\033[38;5;45m'  '\033[38;5;39m'  '\033[38;5;33m'  '\033[38;5;27m'
         '\033[38;5;93m'  '\033[38;5;129m' '\033[38;5;165m' '\033[38;5;201m')

GREY=$'\033[38;5;239m'
DIMG=$'\033[38;5;240m'
BORDER=$'\033[38;5;240m'
LABEL=$'\033[38;5;248m'

# Flower palette (the poppy itself — bright bold)
PETAL_RED=$'\033[1;38;5;9m'
PETAL_MAG=$'\033[1;38;5;13m'
PETAL_PNK=$'\033[1;38;5;218m'
CENTER_YEL=$'\033[1;38;5;11m'
STEM_GRN=$'\033[1;38;5;10m'
LEAF_GRN=$'\033[1;38;5;10m'
GROUND_GRN=$'\033[1;38;5;2m'

# Accents (used in mood text and achievement art)
MAGENTA=$'\033[1;38;5;201m'
CYAN=$'\033[1;38;5;51m'
YELLOW=$'\033[1;38;5;11m'
ORANGE=$'\033[1;38;5;208m'
RED=$'\033[1;38;5;9m'
GREEN_BR=$'\033[38;5;46m'

# Animation frames
SPINNER=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧")


# ─────────────────────────────────────────────────────────────────────
# STATE FILE MIGRATION (gpu-buddy.sh → poppai.sh, one-time)
# ─────────────────────────────────────────────────────────────────────
mkdir -p "$POPPAI_DIR"
for _f in pet_count petted fed last_mood mood_shifts achievement achievements cache_prev gpu_prev; do
    [ -f "$POPPAI_DIR/buddy_$_f" ] && [ ! -f "$POPPAI_DIR/poppai_$_f" ] \
        && mv "$POPPAI_DIR/buddy_$_f" "$POPPAI_DIR/poppai_$_f"
done
rm -f "$POPPAI_DIR/buddy_hat" 2>/dev/null  # never implemented; gone

# State file paths (single source of truth)
S_ACTION="$POPPAI_DIR/poppai_action"
S_PETS="$POPPAI_DIR/poppai_pet_count"
S_PETTED="$POPPAI_DIR/poppai_petted"
S_FED="$POPPAI_DIR/poppai_fed"
S_LAST_MOOD="$POPPAI_DIR/poppai_last_mood"
S_MOOD_SHIFTS="$POPPAI_DIR/poppai_mood_shifts"
S_ACH_NOW="$POPPAI_DIR/poppai_achievement"
S_ACH_LOG="$POPPAI_DIR/poppai_achievements"
S_CACHE_PREV="$POPPAI_DIR/poppai_cache_prev"
S_GPU_PREV="$POPPAI_DIR/poppai_gpu_prev"


# ─────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────

# Read a state file with a default fallback if missing/empty.
read_state() { [ -f "$1" ] && cat "$1" 2>/dev/null || echo "${2:-0}"; }

# Read a state file as an integer. Returns 0 if missing or non-integer.
# Use this for anything that flows into bash arithmetic ((...)) — a raw
# read_state value could embed command substitution via array subscript.
read_int() {
    local v; v=$(read_state "$1" "${2:-0}")
    [[ "$v" =~ ^[0-9]+$ ]] && printf '%s' "$v" || printf '%s' "${2:-0}"
}

# Rainbow gradient bar with partial-block tail (nvitop style).
#   gbar PCT [WIDTH]   — PCT 0..100, WIDTH in chars (default 18)
gbar() {
    local blocks=("" "▏" "▎" "▍" "▌" "▋" "▊" "▉")
    local p=${1:-0} w=${2:-18}
    ((p > 100)) && p=100
    ((p < 0))   && p=0
    local e8=$((p * w * 8 / 100))
    local full=$((e8 / 8)) frac=$((e8 % 8))
    local half=0; ((frac > 0)) && half=1
    local empty=$((w - full - half))
    local i ci nc=${#RAINBOW[@]}
    for ((i=0; i<full; i++)); do
        ci=$((i * nc / w))
        printf '%s█%s' "${RAINBOW[$ci]}" "$RESET"
    done
    if ((frac > 0)); then
        ci=$((full * nc / w))
        printf '%s%s%s' "${RAINBOW[$ci]}" "${blocks[$frac]}" "$RESET"
    fi
    printf '%s' "$GREY"
    for ((i=0; i<empty; i++)); do printf '░'; done
    printf '%s' "$RESET"
}

# Pad a string to a fixed display width with trailing spaces.
pad() { local s=$1 w=${2:-8}; while [ ${#s} -lt "$w" ]; do s="${s} "; done; printf '%s' "$s"; }

# Parse a Claude session JSON field with default.
parse_input() { echo "$INPUT" | jq -r ".${1} // ${2:-0}"; }


# ─────────────────────────────────────────────────────────────────────
# INPUT — Claude session JSON (stdin)
# ─────────────────────────────────────────────────────────────────────
INPUT=$(cat)
MODEL=$(parse_input  'model.display_name'                    '"?"')
PCT=$(parse_input    'context_window.used_percentage'        | cut -d. -f1)
COST=$(parse_input   'cost.total_cost_usd')
RATE_5H=$(parse_input 'rate_limits.five_hour.used_percentage' | cut -d. -f1)
RATE_7D=$(parse_input 'rate_limits.seven_day.used_percentage' | cut -d. -f1)
PCT=${PCT:-0}; RATE_5H=${RATE_5H:-0}; RATE_7D=${RATE_7D:-0}


# ─────────────────────────────────────────────────────────────────────
# METRICS — GPU, CPU, RAM, page cache, inodes, uptime
# ─────────────────────────────────────────────────────────────────────

# GPU (single nvidia-smi call for all four values).
# DGX Spark and other unified-memory devices may return "[N/A]" for some
# fields — sanitize to 0 so arithmetic always succeeds.
read GPU_UTIL GPU_TEMP GPU_POWER GPU_MEM_MIB <<<"$(
    nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.used \
        --format=csv,noheader,nounits 2>/dev/null | head -1 | tr ',' ' '
)"
GPU_POWER=$(echo "${GPU_POWER:-0}" | cut -d. -f1)
sanitize_int() { [[ "$1" =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '0'; }
GPU_UTIL=$(sanitize_int "${GPU_UTIL:-0}")
GPU_TEMP=$(sanitize_int "${GPU_TEMP:-0}")
GPU_POWER=$(sanitize_int "${GPU_POWER:-0}")
GPU_MEM_MIB=$(sanitize_int "${GPU_MEM_MIB:-0}")

# Top GPU process (name + memory)
TOP_PROC=$(nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader 2>/dev/null | head -1)
PROC_NAME=""; PROC_MEM=""
if [ -n "$TOP_PROC" ]; then
    PROC_NAME=$(echo "$TOP_PROC" | cut -d',' -f1 | xargs basename 2>/dev/null)
    PROC_MEM=$(echo "$TOP_PROC" | cut -d',' -f2 | tr -d ' ')
fi

# CPU (loadavg / cores → percent)
CPU_LOAD=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)
CPU_LOAD_INT=$(printf '%.0f' "$CPU_LOAD" 2>/dev/null || echo 0)
CPU_CORES=$(nproc 2>/dev/null || echo 8)
CPU_PCT=$((CPU_LOAD_INT * 100 / CPU_CORES))
((CPU_PCT > 100)) && CPU_PCT=100

# RAM
RAM_USED_M=$(free -m 2>/dev/null | awk '/Mem:/{print $3}')
RAM_TOTAL_M=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')
RAM_USED_G=$((RAM_USED_M / 1024))
RAM_TOTAL_G=$((RAM_TOTAL_M / 1024))
RAM_PCT=0; ((RAM_TOTAL_M > 0)) && RAM_PCT=$((RAM_USED_M * 100 / RAM_TOTAL_M))

# Page cache (Buffers + Cached). On DGX Spark this blocks contiguous CUDA
# context allocation when high; fix with `sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'`.
CACHE_KB=$(awk '/^Buffers:/{b=$2} /^Cached:/{c=$2} END{print b+c}' /proc/meminfo 2>/dev/null)
MEMTOTAL_KB=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)
CACHE_PCT=0; ((${MEMTOTAL_KB:-0} > 0)) && CACHE_PCT=$((CACHE_KB * 100 / MEMTOTAL_KB))
CACHE_GB=$((CACHE_KB / 1024 / 1024))

# Inode usage on /  (df -i shows "files" — same thing on most filesystems)
INO_PCT=$(df -i / 2>/dev/null | awk 'NR==2{gsub("%",""); print $5}')
INO_PCT=${INO_PCT:-0}

# Uptime — seconds, days, and a bar % scaled to UPT_BAR_DAYS
UPTIME_S=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
UPTIME_D=$((UPTIME_S / 86400))
UPT_BAR_PCT=$((UPTIME_D * 100 / UPT_BAR_DAYS))
((UPT_BAR_PCT > 100)) && UPT_BAR_PCT=100

# Time bookkeeping (frame counter + spinner)
T=$(date +%s)
F=$((T % 3))
SPN=${SPINNER[$((T % 8))]}


# ─────────────────────────────────────────────────────────────────────
# ACTIONS — one-shot interactions (pet / feed / dance / status)
# Drop a word into ~/.claude/poppai_action; the file is consumed and
# the corresponding micro-render replaces Poppy for one statusline tick.
# ─────────────────────────────────────────────────────────────────────

ACTION=""
if [ -f "$S_ACTION" ]; then
    ACTION=$(cat "$S_ACTION" 2>/dev/null | tr -d '[:space:]')
    rm -f "$S_ACTION"
fi

case "$ACTION" in
    pet)
        PETS=$(read_int "$S_PETS" 0)
        echo $((PETS + 1)) > "$S_PETS"
        printf " ${BORDER}|${RESET} ${CYAN}~ ~ ~${RESET} ${BORDER}|${RESET}  ${CYAN}hydrating${RESET} ${DIM}bloom+20${RESET}\n"
        printf " ${BORDER}|${RESET} ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}v${PETAL_PNK}^${PETAL_RED})${RESET} ${BORDER}|${RESET}\n"
        printf " ${BORDER}|${RESET}   ${STEM_GRN}┃${LEAF_GRN}❦${RESET}  ${BORDER}|${RESET}\n"
        date +%s > "$S_PETTED"
        exit 0
        ;;
    feed)
        printf " ${BORDER}|${RESET} ${YELLOW}* o *${RESET} ${BORDER}|${RESET}  ${YELLOW}photosynthesis${RESET} ${DIM}-30${RESET}\n"
        printf " ${BORDER}|${RESET} ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}o${PETAL_PNK}^${PETAL_RED})${RESET} ${BORDER}|${RESET}\n"
        printf " ${BORDER}|${RESET}   ${STEM_GRN}┃${LEAF_GRN}❦${RESET}  ${BORDER}|${RESET}\n"
        date +%s > "$S_FED"
        exit 0
        ;;
    dance)
        printf " ${BORDER}|${RESET} ${MAGENTA}* ✿ *${RESET} ${BORDER}|${RESET}  ${MAGENTA}~ sway ~${RESET}\n"
        printf " ${BORDER}|${RESET} ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}o${PETAL_PNK}^${PETAL_RED})${RESET} ${BORDER}|${RESET}\n"
        printf " ${BORDER}|${RESET}  ${STEM_GRN}\\┃${LEAF_GRN}❦${RESET} ${BORDER}|${RESET}\n"
        exit 0
        ;;
    status)
        _PC=$(read_int "$S_PETS" 0)
        _MS=$(read_int "$S_MOOD_SHIFTS" 0)
        _UP=$(uptime -p 2>/dev/null | sed 's/up //')
        _AC=$(wc -l < "$S_ACH_LOG" 2>/dev/null || echo 0)
        _TOT=${#ALL_ACHIEVEMENTS[@]}

        printf "${PETAL_RED}┌──────────────────────────────────────┐${RESET}\n"
        printf "${PETAL_RED}│${RESET}  ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET}  ${BOLD}POPPAI PROFILE${RESET}          ${PETAL_RED}│${RESET}\n"
        printf "${PETAL_RED}├──────────────────────────────────────┤${RESET}\n"
        printf "${PETAL_RED}│${RESET}  ${LABEL}Mood shifts${RESET}  %-23s ${PETAL_RED}│${RESET}\n" "$_MS"
        printf "${PETAL_RED}│${RESET}  ${LABEL}Times petted${RESET} %-23s ${PETAL_RED}│${RESET}\n" "$_PC"
        printf "${PETAL_RED}│${RESET}  ${LABEL}Uptime${RESET}       %-23s ${PETAL_RED}│${RESET}\n" "$_UP"
        printf "${PETAL_RED}│${RESET}  ${LABEL}Achievements${RESET} %-23s ${PETAL_RED}│${RESET}\n" "$_AC / $_TOT"
        printf "${PETAL_RED}├──────────────────────────────────────┤${RESET}\n"
        for entry in "${ALL_ACHIEVEMENTS[@]}"; do
            key="${entry%%:*}"
            desc="${entry#*:}"
            if grep -qx "$key" "$S_ACH_LOG" 2>/dev/null; then
                printf "${PETAL_RED}│${RESET}  ${YELLOW}*${RESET} ${BOLD}%-33s${RESET} ${PETAL_RED}│${RESET}\n" "$desc"
            else
                printf "${PETAL_RED}│${RESET}  ${DIMG}.${RESET} ${DIMG}%-33s${RESET} ${PETAL_RED}│${RESET}\n" "$desc"
            fi
        done
        printf "${PETAL_RED}└──────────────────────────────────────┘${RESET}\n"
        exit 0
        ;;
esac


# ─────────────────────────────────────────────────────────────────────
# MOOD COMPUTATION
# Two internal axes pick Poppy's expression:
#   ENERGY 0..4  — how much useful work is happening
#   STRAIN 0..4  — how close any resource is to its limit
# These are NOT shown directly as bars (the right column is INO/UPT/ACH).
# ─────────────────────────────────────────────────────────────────────

# Energy
ENERGY=0
((GPU_UTIL >= ENERGY_GPU_BLAZING))                  && ENERGY=4
((GPU_UTIL >= ENERGY_GPU_THRIVING && ENERGY < 3))   && ENERGY=3
((GPU_UTIL >= ENERGY_GPU_WORKING  && ENERGY < 2))   && ENERGY=2
((GPU_UTIL >= ENERGY_GPU_ALIVE    && ENERGY < 1))   && ENERGY=1
((CPU_PCT  >= ENERGY_CPU_BUSY     && ENERGY < 2))   && ENERGY=2
((CPU_PCT  >= ENERGY_CPU_PRESENT  && ENERGY < 1))   && ENERGY=1

# Strain
STRAIN=0; STRESSOR=""
set_strain() {
    local lvl=$1 tag=$2
    if ((lvl > STRAIN)); then STRAIN=$lvl; STRESSOR=$tag
    elif [ -z "$STRESSOR" ]; then STRESSOR=$tag; fi
}
((GPU_TEMP >= STRAIN_TEMP_CRIT))                          && set_strain 4 "${GPU_TEMP}C"
((GPU_TEMP >= STRAIN_TEMP_HIGH    && STRAIN < 3))         && set_strain 3 "${GPU_TEMP}C"
((RAM_PCT  >= STRAIN_RAM_CRIT     && STRAIN < 4))         && set_strain 4 "RAM${RAM_PCT}%"
((RAM_PCT  >= STRAIN_RAM_HIGH     && STRAIN < 3))         && set_strain 3 "RAM${RAM_PCT}%"
((RAM_PCT  >= STRAIN_RAM_MED      && STRAIN < 2))         && set_strain 2 "RAM${RAM_PCT}%"
((CACHE_PCT >= STRAIN_CACHE_CRIT  && STRAIN < 4))         && set_strain 4 "cch${CACHE_PCT}%"
((CACHE_PCT >= STRAIN_CACHE_HIGH  && STRAIN < 3))         && set_strain 3 "cch${CACHE_PCT}%"
((CACHE_PCT >= STRAIN_CACHE_MED   && STRAIN < 2))         && set_strain 2 "cch${CACHE_PCT}%"
((PCT      >= STRAIN_CTX_CRIT     && STRAIN < 4))         && set_strain 4 "ctx${PCT}%"
((PCT      >= STRAIN_CTX_HIGH     && STRAIN < 3))         && set_strain 3 "ctx${PCT}%"
((PCT      >= STRAIN_CTX_MED      && STRAIN < 2))         && set_strain 2 "ctx${PCT}%"
((RATE_7D  >= STRAIN_RATE_HIGH    && STRAIN < 3))         && set_strain 3 "7D${RATE_7D}%"
((RATE_7D  >= STRAIN_RATE_MED     && STRAIN < 2))         && set_strain 2 "7D${RATE_7D}%"

# Pet/feed bonuses
PET_TS=$(read_int "$S_PETTED" 0)
FED_TS=$(read_int "$S_FED" 0)
((T - PET_TS < PET_BONUS_SECONDS  && STRAIN > 0)) && STRAIN=$((STRAIN - 1))
((T - FED_TS < FEED_BONUS_SECONDS && STRAIN > 0)) && STRAIN=$((STRAIN - 1))

# Map (energy, strain) → state name
if   ((STRAIN >= 4));      then [ "$ENERGY" -ge 3 ] && ST="overheat" || ST="wilt"
elif ((STRAIN >= 3));      then
    if   ((ENERGY >= 4));  then ST="grind"
    elif ((ENERGY >= 2));  then ST="push"
    else                        ST="strain"
    fi
elif ((STRAIN >= 2));      then
    if   ((ENERGY >= 4));  then ST="fire"
    elif ((ENERGY >= 2));  then ST="focus"
    else                        ST="concern"
    fi
elif ((ENERGY >= 4));      then ST="fire"
elif ((ENERGY >= 3));      then ST="thrive"
elif ((ENERGY >= 2));      then ST="vibe"
elif ((ENERGY >= 1));      then ST="bloom"
elif [ -z "$PROC_NAME" ] && ((GPU_UTIL < 5 && CPU_LOAD_INT < 2)); then ST="seed"
else                            ST="idle"
fi


# ─────────────────────────────────────────────────────────────────────
# ACHIEVEMENT DETECTION
# Each block: check trigger → call `unlock NAME` (writes timestamp).
# Achievements display for ACH_DISPLAY_SECONDS, then revert.
# Adding a new one? Three steps:
#   1. add `"name:description"` to ALL_ACHIEVEMENTS up top
#   2. add a trigger block here
#   3. add an art case in ACHIEVEMENT ART OVERRIDES below
# ─────────────────────────────────────────────────────────────────────

ACH=""; ACH_TS=0
if [ -f "$S_ACH_NOW" ]; then
    _raw_ts=$(cut -d: -f1 < "$S_ACH_NOW" 2>/dev/null)
    [[ "$_raw_ts" =~ ^[0-9]+$ ]] && ACH_TS=$_raw_ts
    ACH=$(cut    -d: -f2- < "$S_ACH_NOW" 2>/dev/null | tr -cd '[:alnum:]_')
fi

unlock() { ACH=$1; echo "${T}:$1" > "$S_ACH_NOW"; }

HOUR=$(date +%H); MIN=$(date +%M); DOW=$(date +%u)
COST_STR=$(printf '%.2f' "$COST")

((GPU_TEMP == 69))                                                        && unlock "nice"
((GPU_UTIL < 20 && CPU_PCT < 20 && RAM_PCT < 50 && CACHE_PCT < 40 \
   && PCT < 40 && GPU_TEMP < 55))                                         && unlock "zen"
((PCT >= 95))                                                             && unlock "edge"
((HOUR < 5))                                                              && unlock "nightowl"
((DOW == 5 && HOUR >= 17 || DOW == 6 || DOW == 7))                        && unlock "weekend"
[ "$COST_STR" = "$ACH_LEET_COST" ]                                        && unlock "leet"
((HOUR == 16 && MIN == 20))                                               && unlock "fourtwenty"
((CACHE_PCT >= STRAIN_CACHE_CRIT))                                        && unlock "chonk"

CACHE_PREV=$(read_int "$S_CACHE_PREV" 0); echo "$CACHE_PCT" > "$S_CACHE_PREV"
((CACHE_PREV >= 50 && CACHE_PCT <= 10))                                   && unlock "drained"

((UPTIME_S   >= ACH_MARATHON_SECONDS))                                    && unlock "marathon"
((GPU_MEM_MIB >= ACH_BIGJOB_MIB))                                         && unlock "bigjob"

GPU_PREV=$(read_int "$S_GPU_PREV" 0); echo "$GPU_UTIL" > "$S_GPU_PREV"
((GPU_PREV >= 80 && GPU_UTIL < 5))                                        && unlock "jobdone"

# New in this release
((GPU_UTIL >= 40 && GPU_UTIL <= 60 && CPU_PCT >= 40 && CPU_PCT <= 60))    && unlock "balanced"
((GPU_UTIL >= 100))                                                       && unlock "throttle"
PETS_NOW=$(read_int "$S_PETS" 0)
((PETS_NOW >= ACH_NEEDY_PETS))                                            && unlock "needy"
((INO_PCT >= ACH_TINYFILES_PCT))                                          && unlock "tinyfiles"

# Expire after ACH_DISPLAY_SECONDS
((T - ACH_TS > ACH_DISPLAY_SECONDS)) && ACH=""

# Log unlocks (dedupe — one line per achievement, exact match)
[ -n "$ACH" ] && ! grep -qx "$ACH" "$S_ACH_LOG" 2>/dev/null && echo "$ACH" >> "$S_ACH_LOG"


# ─────────────────────────────────────────────────────────────────────
# FLOWER ART per state
# Each state sets:
#   F1  — top row (petal crown, 7 visible chars)
#   F2  — middle row (face with petal sides)
#   F3  — stem row
#   F4  — ground row
#   MOOD — short text label (with color + spinner)
#   IC  — single-char mood icon used in the bottom-row mood line
# Animate by setting different art per $F (0..2).
# ─────────────────────────────────────────────────────────────────────

STEM="${STEM_GRN}┃${LEAF_GRN}❦${RESET}"
GROUND="${GROUND_GRN}~~${STEM_GRN}┃${GROUND_GRN}~~${RESET}"

case "$ST" in
    seed)
        F1="       "
        F2="  ${DIMG}(.)${RESET}  "
        F3="   ${GREY}┃${RESET}   "
        F4="  ${GREY}~┃~${RESET}  "
        MOOD="${GREY}seed ${SPN}${RESET}"; IC="◌";;
    idle)
        F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
        F2=" ${PETAL_RED}(${PETAL_PNK}-${CENTER_YEL}w${PETAL_PNK}-${PETAL_RED})${RESET} "
        F3="   ${STEM}  "; F4=" ${GROUND} "
        MOOD="${DIMG}idle ${SPN}${RESET}"; IC="~";;
    bloom)
        case $F in
            0) F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} ";;
            1) F1="${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET}  ";;
            2) F1="  ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET}";;
        esac
        F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}w${PETAL_PNK}^${PETAL_RED})${RESET} "
        F3="   ${STEM}  "; F4=" ${GROUND} "
        MOOD="${GREEN_BR}blooming ${SPN}${RESET}"; IC="✦";;
    vibe)
        case $F in
            0) F1=" ${PETAL_MAG}❀${PETAL_RED}❁${MAGENTA}~${PETAL_RED}❁${PETAL_MAG}❀${RESET} ";;
            1) F1=" ${PETAL_MAG}❀${MAGENTA}~${PETAL_PNK}✿${MAGENTA}~${PETAL_MAG}❀${RESET} ";;
            2) F1=" ${MAGENTA}~${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${MAGENTA}~${RESET} ";;
        esac
        F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}o${PETAL_PNK}^${PETAL_RED})${RESET} "
        F3="   ${STEM}  "; F4=" ${GROUND} "
        MOOD="${MAGENTA}vibing ${SPN}${RESET}"; IC="~";;
    thrive)
        case $F in
            0) F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} ";;
            1) F1="${YELLOW}*${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET}";;
            2) F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${YELLOW}*";;
        esac
        F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}O${PETAL_PNK}^${PETAL_RED})${RESET} "
        F3="  ${YELLOW}*${STEM} "; F4=" ${GROUND} "
        MOOD="${GREEN_BR}${BOLD}thriving ${SPN}${RESET}"; IC="*";;
    fire)
        case $F in
            0) F1="${YELLOW}*${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} ";;
            1) F1=" ${PETAL_MAG}❀${PETAL_RED}❁${YELLOW}*${PETAL_PNK}✿${YELLOW}*${PETAL_RED}❁${RESET} ";;
            2) F1=" ${PETAL_RED}❁${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${PETAL_RED}❁${YELLOW}*";;
        esac
        F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}O${PETAL_PNK}^${PETAL_RED})${RESET} "
        F3="  ${YELLOW}*${STEM_GRN}┃${YELLOW}*${LEAF_GRN}❦${RESET} "
        F4=" ${YELLOW}*${GROUND_GRN}~${STEM_GRN}┃${GROUND_GRN}~${YELLOW}*${RESET} "
        MOOD="${YELLOW}${BOLD}BLAZING ${SPN}${RESET}"; IC="*";;
    focus)
        F1=" ${PETAL_MAG}❀${PETAL_RED}❁${CYAN}!${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
        case $F in
            0) F2=" ${PETAL_RED}(${PETAL_PNK}◉${CENTER_YEL}.${PETAL_PNK}◉${PETAL_RED})${RESET} ";;
            1) F2=" ${PETAL_RED}(${PETAL_PNK}◉${CENTER_YEL}◉${PETAL_PNK}◉${PETAL_RED})${RESET} ";;
            2) F2=" ${PETAL_RED}(${PETAL_PNK}◉${CENTER_YEL}.${PETAL_PNK}◉${PETAL_RED})${RESET} ";;
        esac
        F3="   ${STEM}  "; F4=" ${GROUND} "
        MOOD="${CYAN}focused ${SPN}${RESET}"; IC="◉";;
    grind)
        case $F in
            0) F1=" ${PETAL_MAG}❀${PETAL_RED}❁${CYAN}!${PETAL_RED}❁${PETAL_MAG}❀${RESET} ";;
            1) F1=" ${CYAN}!${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${RESET} ";;
            2) F1=" ${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${CYAN}!${RESET} ";;
        esac
        F2=" ${PETAL_RED}(${PETAL_PNK}>${CENTER_YEL}o${PETAL_PNK}<${PETAL_RED})${RESET} "
        F3="   ${STEM}  "; F4=" ${GROUND} "
        MOOD="${CYAN}${BOLD}grinding ${SPN}${RESET}"; IC="⌨";;
    concern)
        F1=" ${ORANGE}~${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${ORANGE}~${RESET} "
        F2=" ${PETAL_RED}(${PETAL_PNK}?${CENTER_YEL}.${PETAL_PNK}?${PETAL_RED})${RESET} "
        F3="   ${STEM}  "; F4=" ${GROUND} "
        MOOD="${ORANGE}concerned ${SPN}${RESET}"; IC="?";;
    strain|push)
        F1=" ${ORANGE}~${PETAL_MAG}❀${ORANGE}~${PETAL_MAG}❀${ORANGE}~${RESET} "
        F2=" ${ORANGE}(${YELLOW}>${CENTER_YEL}.${YELLOW}<${ORANGE})${RESET} "
        F3="   ${STEM_GRN}┃${DIMG}❧${RESET}  "; F4=" ${GROUND} "
        MOOD="${ORANGE}strained ${SPN}${RESET}"; IC="!";;
    wilt)
        F1="  ${ORANGE}~${YELLOW}~${ORANGE}~${RESET}  "
        case $F in
            0) F2=" ${ORANGE}(${YELLOW}u${CENTER_YEL}.${YELLOW}u${ORANGE})${RESET} ";;
            1) F2=" ${ORANGE}(${YELLOW}-${CENTER_YEL}.${YELLOW}-${ORANGE})${RESET} ";;
            2) F2=" ${ORANGE}(${YELLOW}u${CENTER_YEL}.${YELLOW}u${ORANGE})${RESET} ";;
        esac
        F3="   ${STEM_GRN}┃${DIMG}❧${RESET}  "
        F4=" ${GROUND_GRN}~~${STEM_GRN}┃${GROUND_GRN}~~${RESET} "
        MOOD="${ORANGE}${BOLD}wilting ${SPN}${RESET}"; IC="▼";;
    overheat)
        case $F in
            0) F1=" ${RED}!${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${RED}!${RESET} ";;
            1) F1="${RED}!${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${RED}!${RESET}  ";;
            2) F1="  ${RED}!${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${RED}!";;
        esac
        F2=" ${RED}(${ORANGE}>${CENTER_YEL}o${ORANGE}<${RED})${RESET} "
        F3="  ${RED}!${STEM_GRN}┃${DIMG}❧${RESET} "
        F4=" ${RED}!${GROUND_GRN}~${STEM_GRN}┃${GROUND_GRN}~${RED}!${RESET} "
        MOOD="${RED}${BOLD}overheat ${SPN}${RESET}"; IC="!";;
    *)
        F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
        F2=" ${PETAL_RED}(${PETAL_PNK}.${CENTER_YEL}.${PETAL_PNK}.${PETAL_RED})${RESET} "
        F3="   ${STEM}  "; F4=" ${GROUND} "
        MOOD="${DIMG}unknown ${SPN}${RESET}"; IC="?";;
esac


# ─────────────────────────────────────────────────────────────────────
# ACHIEVEMENT ART OVERRIDES
# When an achievement is fresh (within ACH_DISPLAY_SECONDS), replace the
# state's flower art with this celebratory variant.
# ─────────────────────────────────────────────────────────────────────

if [ -n "$ACH" ]; then
    case "$ACH" in
        nice)
            F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
            F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}w${PETAL_PNK}~${PETAL_RED})${RESET} "
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${MAGENTA}nice ${SPN}${RESET}"; IC=";";;
        balanced)
            F1=" ${CYAN}=${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${CYAN}=${RESET} "
            F2=" ${PETAL_RED}(${CYAN}-${CENTER_YEL}o${CYAN}-${PETAL_RED})${RESET} "
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${CYAN}balanced ${SPN}${RESET}"; IC="=";;
        zen)
            F1="  ${CYAN}. . .${RESET}  "
            F2=" ${PETAL_RED}(${CYAN}-${CENTER_YEL}o${CYAN}-${PETAL_RED})${RESET} "
            F3="   ${STEM}  "
            F4=" ${CYAN}~${GROUND_GRN}~${STEM_GRN}┃${GROUND_GRN}~${CYAN}~${RESET} "
            MOOD="${CYAN}${BOLD}zen ${SPN}${RESET}"; IC="o";;
        throttle)
            case $F in
                0) F1="${YELLOW}*${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${YELLOW}*";;
                1) F1="${YELLOW}*${PETAL_RED}❁${YELLOW}*${PETAL_PNK}✿${YELLOW}*${PETAL_RED}❁${YELLOW}*";;
                2) F1="${YELLOW}*${PETAL_MAG}❀${YELLOW}*${PETAL_PNK}✿${YELLOW}*${PETAL_MAG}❀${YELLOW}*";;
            esac
            F2=" ${PETAL_RED}(${YELLOW}!${CENTER_YEL}O${YELLOW}!${PETAL_RED})${RESET} "
            F3="  ${YELLOW}*${STEM_GRN}┃${YELLOW}*${LEAF_GRN}❦${RESET} "
            F4=" ${YELLOW}*${YELLOW}*${STEM_GRN}┃${YELLOW}*${YELLOW}*${RESET} "
            MOOD="${YELLOW}${BOLD}FULL THROTTLE ${SPN}${RESET}"; IC="!";;
        edge)
            F1=" ${PETAL_MAG}❀${PETAL_RED}❁${ORANGE}!${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
            F2=" ${PETAL_RED}(${ORANGE}o${CENTER_YEL}.${ORANGE}o${PETAL_RED})${RESET} "
            F3="   ${STEM_GRN}┃${RESET}   "
            F4="${ORANGE}==${STEM_GRN}┃${ORANGE}==${RESET} "
            MOOD="${ORANGE}${BOLD}on the edge ${SPN}${RESET}"; IC="!";;
        nightowl)
            F1=" ${DIMG}*${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${DIMG}*${RESET} "
            F2=" ${PETAL_RED}(${DIMG}o${CENTER_YEL}.${DIMG}o${PETAL_RED})${RESET} "
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${DIMG}night owl ${SPN}${RESET}"; IC="*";;
        weekend)
            case $F in
                0) F1=" ${MAGENTA}~${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${MAGENTA}~${RESET} ";;
                1) F1="${MAGENTA}~${PETAL_MAG}❀${MAGENTA}~${PETAL_PNK}✿${MAGENTA}~${PETAL_MAG}❀${MAGENTA}~";;
                2) F1=" ${MAGENTA}~${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${MAGENTA}~${RESET} ";;
            esac
            F2=" ${PETAL_RED}(${MAGENTA}^${CENTER_YEL}v${MAGENTA}^${PETAL_RED})${RESET} "
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${MAGENTA}weekend ${SPN}${RESET}"; IC="~";;
        leet)
            case $F in
                0) F1=" ${CYAN}/${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${CYAN}\\${RESET} ";;
                1) F1=" ${CYAN}\\${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${CYAN}/${RESET} ";;
                2) F1=" ${CYAN}/${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${CYAN}\\${RESET} ";;
            esac
            F2=" ${CYAN}(${CYAN}1${CENTER_YEL}3${CYAN}3${CYAN}7${CYAN})${RESET} "
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${CYAN}${BOLD}LEET ${SPN}${RESET}"; IC="#";;
        fourtwenty)
            F1=" ${GREEN_BR}~${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${GREEN_BR}~${RESET} "
            F2=" ${PETAL_RED}(${GREEN_BR}-${CENTER_YEL}v${GREEN_BR}-${PETAL_RED})${RESET} "
            F3="   ${STEM}  "
            F4=" ${GREEN_BR}~${GROUND_GRN}~${STEM_GRN}┃${GROUND_GRN}~${GREEN_BR}~${RESET} "
            MOOD="${GREEN_BR}chill ${SPN}${RESET}"; IC="~";;
        jobdone)
            F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
            case $F in
                0) F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}o${PETAL_PNK}^${PETAL_RED})${RESET} ";;
                1) F2="  ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}o${PETAL_PNK}^${PETAL_RED}) ";;
                2) F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}o${PETAL_PNK}^${PETAL_RED})${RESET} ";;
            esac
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${GREEN_BR}${BOLD}job done ${SPN}${RESET}"; IC="✓";;
        needy)
            F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
            F2=" ${PETAL_MAG}(${PETAL_PNK}/${CENTER_YEL}/${PETAL_PNK}/${PETAL_MAG})${RESET} "
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${PETAL_MAG}needy ${SPN}${RESET}"; IC="<3";;
        # ── newer celebrations — give every achievement a moment ──
        chonk)
            F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
            F2=" ${PETAL_RED}(${PETAL_PNK}o${CENTER_YEL}A${PETAL_PNK}o${PETAL_RED})${RESET} "
            F3="   ${STEM_GRN}┃${LEAF_GRN}❦${RESET}  "
            F4=" ${GROUND} "
            MOOD="${ORANGE}thicc cache ${SPN}${RESET}"; IC="≋";;
        drained)
            case $F in
                0) F1=" ${CYAN}*${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${CYAN}*${RESET} ";;
                1) F1="${CYAN}*${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${CYAN}*${RESET} ";;
                2) F1=" ${PETAL_MAG}❀${CYAN}*${PETAL_PNK}✿${CYAN}*${PETAL_MAG}❀${RESET} ";;
            esac
            F2=" ${PETAL_RED}(${CYAN}^${CENTER_YEL}o${CYAN}^${PETAL_RED})${RESET} "
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${CYAN}${BOLD}drained! ${SPN}${RESET}"; IC="✦";;
        marathon)
            F1=" ${YELLOW}*${PETAL_MAG}❀${PETAL_PNK}✿${PETAL_MAG}❀${YELLOW}*${RESET} "
            F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}_${PETAL_PNK}^${PETAL_RED})${RESET} "
            F3="  ${YELLOW}7d${STEM_GRN}┃${LEAF_GRN}❦${RESET} "
            F4=" ${GROUND} "
            MOOD="${YELLOW}${BOLD}marathon ${SPN}${RESET}"; IC="★";;
        bigjob)
            F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
            F2=" ${PETAL_RED}(${PETAL_PNK}O${CENTER_YEL}_${PETAL_PNK}O${PETAL_RED})${RESET} "
            F3="   ${STEM}  "; F4=" ${GROUND} "
            MOOD="${YELLOW}big job ${SPN}${RESET}"; IC="◆";;
        tinyfiles)
            F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
            F2=" ${PETAL_RED}(${ORANGE}.${CENTER_YEL}o${ORANGE}.${PETAL_RED})${RESET} "
            F3="   ${STEM_GRN}┃${DIMG}…${RESET}  "
            F4=" ${ORANGE}.${GROUND_GRN}~${STEM_GRN}┃${GROUND_GRN}~${ORANGE}.${RESET} "
            MOOD="${ORANGE}tiny files ${SPN}${RESET}"; IC="·";;
    esac
fi


# ─────────────────────────────────────────────────────────────────────
# RENDER — 4 lines: flower box | 3-column stat grid
#
#   Row 1: petals  | GPU  | CPU  | INO     (load + filesystem inode %)
#   Row 2: face    | RAM  | CCH  | UPT     (page cache + days uptime)
#   Row 3: stem    | CTX  | 7D   | ACH     (achievements out of total)
#   Row 4: ground  | mood + model + process + stressor
# ─────────────────────────────────────────────────────────────────────

# Mood shift counter
LAST_MOOD=$(read_state "$S_LAST_MOOD" "" | tr -cd '[:alnum:]_')
MOOD_SHIFTS=$(read_int "$S_MOOD_SHIFTS" 0)
[ "$ST" != "$LAST_MOOD" ] && [ -n "$LAST_MOOD" ] && MOOD_SHIFTS=$((MOOD_SHIFTS + 1))
echo "$ST"          > "$S_LAST_MOOD"
echo "$MOOD_SHIFTS" > "$S_MOOD_SHIFTS"

# Achievement bar
ACH_COUNT=$(wc -l < "$S_ACH_LOG" 2>/dev/null || echo 0)
ACH_TOTAL=${#ALL_ACHIEVEMENTS[@]}
ACH_BAR_PCT=$((ACH_COUNT * 100 / ACH_TOTAL))
((ACH_BAR_PCT > 100)) && ACH_BAR_PCT=100

# Tags shown at the right of the mood line
STAG=""
((STRAIN >= 2)) && [ -n "$STRESSOR" ] && STAG=" ${DIMG}(${STRESSOR})${RESET}"
PTAG=""
if [ -n "$PROC_NAME" ]; then
    PTAG="  ${DIMG}▸ ${PROC_NAME}${RESET}"
    [ -n "$PROC_MEM" ] && PTAG="  ${DIMG}▸ ${PROC_NAME} ${PROC_MEM}${RESET}"
fi

SEP="${BORDER}│${RESET}"

# Padded value strings — keep separators aligned
VL1=$(pad "${GPU_UTIL}% ${GPU_TEMP}C" 8)
VL2=$(pad "${RAM_USED_G}/${RAM_TOTAL_G}G" 8)
VL3=$(pad "${PCT}%" 8)
VM1=$(pad "${CPU_PCT}% ld${CPU_LOAD}" 11)
VM2=$(pad "${CACHE_GB}G ${CACHE_PCT}%" 11)
VM3=$(pad "${RATE_7D}%" 11)
VR1=$(pad "${INO_PCT}%" 8)
VR2=$(pad "${UPTIME_D}d" 8)
VR3=$(pad "${ACH_COUNT}/${ACH_TOTAL}" 8)

echo -e " ${BORDER}|${RESET}${F1}${BORDER}|${RESET} ${LABEL}GPU${RESET} $(gbar "$GPU_UTIL"    7) ${VL1}${SEP} ${LABEL}CPU${RESET} $(gbar "$CPU_PCT"    7) ${VM1}${SEP} ${LABEL}INO${RESET} $(gbar "$INO_PCT"     4) ${VR1}"
echo -e " ${BORDER}|${RESET}${F2}${BORDER}|${RESET} ${LABEL}RAM${RESET} $(gbar "$RAM_PCT"     7) ${VL2}${SEP} ${LABEL}CCH${RESET} $(gbar "$CACHE_PCT"  7) ${VM2}${SEP} ${LABEL}UPT${RESET} $(gbar "$UPT_BAR_PCT" 4) ${VR2}"
echo -e " ${BORDER}|${RESET}${F3}${BORDER}|${RESET} ${LABEL}CTX${RESET} $(gbar "$PCT"        7) ${VL3}${SEP} ${LABEL}7D ${RESET} $(gbar "$RATE_7D"    7) ${VM3}${SEP} ${LABEL}ACH${RESET} $(gbar "$ACH_BAR_PCT" 4) ${VR3}"
echo -ne " ${BORDER}|${RESET}${F4}${BORDER}|${RESET}"
printf "  %s  %b%b   ${BOLD}${MAGENTA}%s${RESET}%b\n" "$IC" "$MOOD" "$STAG" "$MODEL" "$PTAG"
