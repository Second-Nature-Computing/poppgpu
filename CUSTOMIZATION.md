# Customizing PoppGPU

PoppGPU is one bash script (`poppgpu.sh`) with a big `CONFIG` block at the top. Most changes are find-the-constant and edit-it. Here's the tour.

## Where things live

The script is split into clearly labeled sections (search for `─────`):

| Section | What's in it |
|---|---|
| **CONFIG** | Thresholds, colors, achievement registry, pet/feed durations. **Almost everything you'd want to change is here.** |
| **HELPERS** | `gbar` (the rainbow bar), `pad`, `read_state`, `read_int`, `parse_input` |
| **INPUT** | Parses the Claude session JSON from stdin |
| **METRICS** | Collects GPU / CPU / RAM / page cache / inode / uptime |
| **ACTIONS** | The four one-shot interactions (`pet`, `feed`, `dance`, `status`) |
| **MOOD COMPUTATION** | The two-axis ENERGY × STRAIN → state machine |
| **ACHIEVEMENT DETECTION** | One block per achievement trigger |
| **FLOWER ART** | Per-state 4-line ASCII flower (11 states) |
| **ACHIEVEMENT ART OVERRIDES** | Special flower art per achievement (16 states) |
| **RENDER** | Final 4-line output |

## Change the colors

The bar uses a 24-stop rainbow gradient. To make it blue-only, replace `RAINBOW` with one color repeated:

```bash
RAINBOW=('\033[38;5;33m')   # everything is blue
```

To change the poppy itself:

```bash
PETAL_RED=$'\033[1;38;5;9m'      # the outer petals — try 200 for hot pink
PETAL_MAG=$'\033[1;38;5;13m'     # secondary petals
PETAL_PNK=$'\033[1;38;5;218m'    # inner petals
CENTER_YEL=$'\033[1;38;5;11m'    # the flower's eye/center
STEM_GRN=$'\033[1;38;5;10m'      # stem
LEAF_GRN=$'\033[1;38;5;10m'      # the leaf
GROUND_GRN=$'\033[1;38;5;2m'     # the ground tildes
```

xterm 256-color cheat sheet: https://www.ditig.com/256-colors-cheat-sheet

## Change the thresholds

These determine when the flower looks stressed:

```bash
STRAIN_TEMP_CRIT=85       # 'overheat' kicks in when GPU >= this
STRAIN_CACHE_CRIT=80      # drop_caches threshold (DGX Spark specific)
STRAIN_CTX_HIGH=75        # context window pressure
# ... etc
```

Lower values = a more anxious flower. Higher values = a chill flower that only stresses at extremes.

## Add a new achievement

Three places to edit. All near the top of the file.

**1.** Add the name + description to `ALL_ACHIEVEMENTS`:

```bash
ALL_ACHIEVEMENTS=(
    ...existing...
    "myach:Got my custom condition"
)
```

**2.** Add the detection in the `ACHIEVEMENT DETECTION` section:

```bash
# Trigger when GPU memory used is exactly 42 GiB
((GPU_MEM_MIB == 43008))    && unlock "myach"
```

**3.** Add a flower-art case in `ACHIEVEMENT ART OVERRIDES`:

```bash
myach)
    F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
    F2=" ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}o${PETAL_PNK}^${PETAL_RED})${RESET} "
    F3="   ${STEM}  "
    F4=" ${GROUND} "
    MOOD="${YELLOW}custom unlocked ${SPN}${RESET}"
    IC="*"
    ;;
```

That's it. The achievement is now in the `status` profile card and contributes to the `ACH X/Y` bar.

## Change the flower's expression for a mood

Find the case in `FLOWER ART per state` and edit. Each state has 4 lines (F1 petals, F2 face, F3 stem, F4 ground) plus a MOOD label and an IC icon used in the bottom row.

Example — make the `idle` state look bored instead of sleepy:

```bash
idle)
    F1=" ${PETAL_MAG}❀${PETAL_RED}❁${PETAL_PNK}✿${PETAL_RED}❁${PETAL_MAG}❀${RESET} "
    F2=" ${PETAL_RED}(${PETAL_PNK}-${CENTER_YEL}_${PETAL_PNK}-${PETAL_RED})${RESET} "
    F3="   ${STEM}  "
    F4=" ${GROUND} "
    MOOD="${DIMG}bored ${SPN}${RESET}"
    IC="~";;
```

Use multi-frame animation by branching on `$F` (a value of 0, 1, or 2 that ticks each statusline render):

```bash
case $F in
    0) F2=" ${PETAL_RED}(${PETAL_PNK}-${CENTER_YEL}_${PETAL_PNK}-${PETAL_RED})${RESET} ";;
    1) F2=" ${PETAL_RED}(${PETAL_PNK}o${CENTER_YEL}_${PETAL_PNK}o${PETAL_RED})${RESET} ";;
    2) F2=" ${PETAL_RED}(${PETAL_PNK}-${CENTER_YEL}_${PETAL_PNK}-${PETAL_RED})${RESET} ";;
esac
```

## Tune the pet/feed effects

How long should pampering keep her chill?

```bash
PET_BONUS_SECONDS=300      # 5 minutes of strain relief per pet
FEED_BONUS_SECONDS=600     # 10 minutes per feed
```

## Adjust the uptime bar scale

By default the UPT bar fills at 14 days. On a machine you reboot weekly, lower this so the bar fills sooner:

```bash
UPT_BAR_DAYS=7    # bar full at 7 days
```

## Swap a stat in the right column

The right column is currently INO / UPT / ACH. Each is one line in the RENDER section. To put something else there, edit:

- Row 1's INO line: change `gbar "$INO_PCT"` and the `VR1` value
- Row 2's UPT line: change `gbar "$UPT_BAR_PCT"` and the `VR2` value
- Row 3's ACH line: change `gbar "$ACH_BAR_PCT"` and the `VR3` value

If you want a totally new metric, collect it in the METRICS section first, then reference its variable in RENDER.

## Add a new action

Actions are the `case "$ACTION"` block. To add a new `wave` action:

```bash
wave)
    printf " ${BORDER}|${RESET} ${CYAN}~ wave ~${RESET} ${BORDER}|${RESET}  ${CYAN}greetings${RESET}\n"
    printf " ${BORDER}|${RESET} ${PETAL_RED}(${PETAL_PNK}^${CENTER_YEL}o${PETAL_PNK}^${PETAL_RED})${RESET}/ ${BORDER}|${RESET}\n"
    printf " ${BORDER}|${RESET}   ${STEM_GRN}┃${LEAF_GRN}❦${RESET}  ${BORDER}|${RESET}\n"
    exit 0
    ;;
```

Then trigger it from anywhere:

```bash
echo wave > ~/.claude/poppgpu_action
```

## State files reference

PoppGPU keeps state in `~/.claude/poppgpu_*` files (text, one value per file, easy to inspect or reset):

| File | Contents |
|---|---|
| `poppgpu_action` | One-shot action queue (consumed on next render) |
| `poppgpu_pet_count` | Cumulative number of times pet |
| `poppgpu_petted` | Unix timestamp of last pet (strain bonus tracking) |
| `poppgpu_fed` | Unix timestamp of last feed |
| `poppgpu_last_mood` | Previous state name (for mood-shift counting) |
| `poppgpu_mood_shifts` | Total mood transitions over time |
| `poppgpu_achievement` | Currently-displayed achievement + unlock timestamp |
| `poppgpu_achievements` | One-line-per-achievement unlocked log |
| `poppgpu_cache_prev` | Previous tick's page cache % (for `drained` detection) |
| `poppgpu_gpu_prev` | Previous tick's GPU % (for `jobdone` detection) |

To wipe her memory and start fresh: `rm ~/.claude/poppgpu_*`. To export her achievements as a brag: `cat ~/.claude/poppgpu_achievements`.

## Reach further

If your customization gets weird, PoppGPU is happy with that. Themes, alternate flowers (sunflower? cactus?), seasonal variants, holiday achievements — open a PR, fork it, whatever.
