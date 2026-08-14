# Changelog

## 0.2.0 — 2026-08-14

Rebrand: PoppAI is now **PoppGPU**.

- `poppai.sh` → `poppgpu.sh`; state files move from `~/.claude/poppai_*` to `~/.claude/poppgpu_*` (one-time automatic migration, covering the original `buddy_*` files too — pet counts and achievements survive)
- Installer flag `--poppai` → `--poppgpu`; installs to `~/.claude/poppgpu.sh`
- Docs updated; fixed the sample test JSON in CONTRIBUTING.md to match the real Claude session schema

## 0.1.0 — 2026-05-28

Initial release.

- `poppgpu.sh` — terminal flower statusline with 11 moods, 16 achievements, four interactions (pet / feed / dance / status), animated ASCII art, rainbow gradient bars
- `statusline-compact.sh` — single-line variant (model / context / cost / GPU bar / top process)
- `statusline.sh` — multi-line variant that staples Claude session info onto a full nvitop dashboard
- `install.sh` — picks a variant, copies it to `~/.claude/poppgpu.sh`, wires it into `settings.json`
- Three docs: `README.md`, `CUSTOMIZATION.md`, `CONTRIBUTING.md`
- MIT licensed
