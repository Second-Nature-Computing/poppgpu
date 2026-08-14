# PoppGPU

A small flower that lives in your [Claude Code](https://docs.anthropic.com/en/docs/claude-code) statusline and reacts to what your machine is doing.

```
 | ❀❁✿❁❀ |  GPU ▉░░░░░░ 14% 52C │ CPU █░░░░░░ 15% ld2.67 │ INO ████░ 100%
 | (>.<) |  RAM ▍░░░░░░ 8/121G  │ CCH █████▌░░ 81G 66%   │ UPT ░░░░  3d
 |  ┃❧   |  CTX █████▍░ 63%     │ 7D  ██▋░░░░ 38%        │ ACH ███░ 12/16
 | ~┃~~  |  ! strained ⠋ (cch66%)  Opus 4.7 (1M context)  ▸ vllm 92GiB
```

She has 11 moods, 16 achievements, and three things you can do to her (pet, feed, dance). She knows when your GPU is on fire, when your page cache is about to wreck your CUDA allocator, when your inode count is creeping toward catastrophe, and when it's 4:20.

She lives next to the regular stats. If you don't want her, there are two simpler variants in the same repo (a single-line bar-graph view, and a full-screen `nvitop` dump).

## Three variants

| Variant | What it is | When to pick it |
|---|---|---|
| **PoppGPU** (`poppgpu.sh`) | The flower above, four lines, animated, with 16 achievements | You want a friend |
| **Compact** (`statusline-compact.sh`) | One line: model · ctx bar · cost · GPU bar · top process | You want a statusline, not a friend |
| **Full** (`statusline.sh`) | Multi-line `nvitop` output stapled to the Claude session header | You want the whole `nvitop` dashboard in your statusline |

## Install

```bash
git clone https://github.com/Second-Nature-Computing/poppgpu.git
cd poppgpu
./install.sh                  # installs PoppGPU by default
./install.sh --compact        # or the compact single-line variant
./install.sh --full           # or the full nvitop dashboard
```

The installer copies the chosen script to `~/.claude/poppgpu.sh`, sets `statusLine.command` in `~/.claude/settings.json`, and that's it. Restart Claude Code to see the new statusline.

To switch variants later, run `./install.sh --<variant>` again.

## What the bars mean

| Bar | Source | What you care about |
|---|---|---|
| **GPU** | `nvidia-smi utilization.gpu` + `temperature.gpu` | Is the GPU actually doing work / cooking |
| **CPU** | `/proc/loadavg` ÷ `nproc` | CPU pressure (load average as a percentage) |
| **RAM** | `free -m` | System RAM use |
| **CCH** | `Buffers + Cached` from `/proc/meminfo` | Page cache. On DGX Spark, ≥80% blocks contiguous CUDA context allocation — drop with `sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'` |
| **CTX** | Claude session JSON | Context window used percentage |
| **7D** | Claude session JSON | Anthropic 7-day rate limit usage |
| **INO** | `df -i /` | Inode usage on `/`. Hits 100% when something fills the filesystem with tiny files (looking at you, `~/.cache/huggingface`) even if disk space is fine |
| **UPT** | `/proc/uptime` | Days since reboot. Bar full at 14 days; reboot recommended sometime before that on DGX Spark to clear page-cache fragmentation |
| **ACH** | `~/.claude/poppgpu_achievements` | Achievements unlocked / total |

The last line is the flower's mood + your model + the top GPU process. If something's stressing her, you'll see a `(stressor)` tag — `(cch66%)`, `(RAM89%)`, `(ctx91%)` etc.

## Talking to her

You can write a one-word action to `~/.claude/poppgpu_action` and she will react on her next statusline tick:

```bash
echo pet    > ~/.claude/poppgpu_action   # pet (boosts mood, increments pet count)
echo feed   > ~/.claude/poppgpu_action   # photosynthesis (strain -1 for 10 minutes)
echo dance  > ~/.claude/poppgpu_action   # 'do a little dance'
echo status > ~/.claude/poppgpu_action   # profile card with all 16 achievements
```

Pet her enough and she'll unlock the **needy** achievement.

## Achievements (16)

Some you'll get the first day. Some take longer. A few are jokes.

| Name | Trigger |
|---|---|
| nice | GPU temperature reads 69°C |
| zen | All stats green at once |
| edge | Context window past 95% |
| nightowl | Statusline rendered before 5 AM |
| weekend | Friday after 5 PM, or Sat/Sun |
| leet | Session cost lands exactly at $13.37 |
| fourtwenty | 4:20 PM local time |
| jobdone | GPU dropped from ≥80% to <5% (you finished something) |
| chonk | Page cache hit the `drop_caches` threshold |
| drained | Page cache went from heavy (≥50%) to fresh (≤10%) — caught a `drop_caches` |
| marathon | Uptime hit 7 days |
| bigjob | GPU memory usage hit 70 GiB+ |
| balanced | GPU and CPU both in the 40-60% range |
| throttle | GPU pinned at 100% |
| needy | Petted 10+ times |
| tinyfiles | Inode usage on `/` hit 80% |

## Customization

PoppGPU is one bash script with a big CONFIG block at the top. Everything you'd want to change is there:

- **Thresholds** — when does the flower start to look stressed? `STRAIN_TEMP_HIGH=75` etc.
- **Colors** — entire palette is named constants. Swap the rainbow for your theme.
- **Achievement criteria** — every detection rule is a separate line. Add your own.
- **Flower art** — each mood is a separate `case` block. Change her face, give her a hat, whatever you want.

See [CUSTOMIZATION.md](./CUSTOMIZATION.md) for a tour of the script with copy-pasteable examples.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 2.0+ (for the statusline hook)
- `jq` (parse the Claude session JSON)
- `nvidia-smi` (GPU metrics)
- `nvitop` only if you want the `--full` variant (`pip install nvitop`)

Tested on DGX Spark (GB10 / SM121a) and various RTX 50-series setups. If you're on a non-NVIDIA machine, the bars will read 0% but nothing crashes.

## Origin

Built at [Second Nature Computing](https://joinsecondnature.com) because we wanted to know how our DGX Spark was feeling at a glance.

## Contributing

Issues, ideas, new achievements, alternate flower designs, themes — yes please. See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

MIT. Fork it, rename it, dress it up however you want.
