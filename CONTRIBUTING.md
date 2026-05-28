# Contributing to PoppAI

PoppAI is a single bash script that draws a flower. The contribution bar is low. Open a PR.

## Things that are very welcome

- **New achievements.** Got a fun condition to detect? Add it. See [CUSTOMIZATION.md → Add a new achievement](./CUSTOMIZATION.md#add-a-new-achievement) for the three places to edit.
- **Alternate flowers.** Cactus, sunflower, mushroom, succulent — any 4-line ASCII botanical. Drop it in as a theme switch.
- **Themes.** The whole color palette is named constants. Dracula, Solarized, Gruvbox, whatever you like.
- **New metrics for the right column.** INO and UPT replaced an older NRG/STR layout because they were more useful day-to-day. Make a case for a swap and we'll consider it.
- **Bug fixes.** Especially around non-NVIDIA machines, BSDs, or anywhere the assumptions break.

## Things to think twice about

- **Adding dependencies.** PoppAI uses bash + `jq` + `nvidia-smi` + maybe `nvitop`. That's it. New deps need a strong reason.
- **Breaking the four-line layout.** The render is sized to be a comfortable statusline height. If you add a fifth row, it stops fitting on narrow terminals.
- **Removing customization knobs.** The whole point of the script is that the CONFIG block is editable. Don't hardcode things that used to be variables.

## Style

- Plain technical writing. No marketing voice in comments, no "leverages / utilizes / robust / comprehensive / seamless / powerful".
- Lowercase log lines. The whole script is friendly-casual, not formal.
- Don't add comments that just restate the code. Comments should explain *why* (e.g. "DGX Spark page cache wrecks CUDA allocator at ≥80%, that's why the threshold is here").
- One change per PR if possible. A new achievement + a new theme + a bug fix should be three PRs.

## Testing your changes

There's no test suite (it's a bash script). To sanity check:

```bash
# Render once with a fake Claude session JSON:
echo '{"model":{"display_name":"Opus 4.7"},"context_window":{"used_percent":63},"total_cost_usd":0.42}' \
    | ./poppai.sh

# Trigger each action:
echo pet > ~/.claude/poppai_action
./poppai.sh < /dev/null
echo feed > ~/.claude/poppai_action
./poppai.sh < /dev/null
echo dance > ~/.claude/poppai_action
./poppai.sh < /dev/null
echo status > ~/.claude/poppai_action
./poppai.sh < /dev/null

# Force each mood by tweaking the env it reads:
GPU_UTIL_OVERRIDE=95 ./poppai.sh < /dev/null   # (you'll need to wire this in if testing locally)
```

For achievements that rely on real metrics (GPU temp, page cache, inode count), the easiest test is to set the threshold artificially low in the CONFIG block and run on real hardware.

## Pull request format

- Title: short, present tense. e.g. "add sunflower theme", "fix inode parser on macOS"
- Body: what changed and why. Screenshots/recordings of new visuals are very welcome.
- Mention any new config knobs in the PR body so they end up in the CHANGELOG.

## Credit

Maintained by [Second Nature Computing](https://joinsecondnature.com). Contributors get credit in the CHANGELOG and our gratitude.
