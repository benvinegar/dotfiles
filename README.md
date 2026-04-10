# Dotfiles

Personal configuration files, managed with symlinks.

## Setup on a new machine

```bash
git clone git@github.com:benvinegar/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

`install.sh` manages:
- `~/.tmux.conf` via symlink
- tmux helper scripts into `~/bin/` via symlink
- `~/.codex/config.toml` via copy
- shared agent skills into `~/.agents/skills` via symlink
- shared agent skills into `~/.claude/skills` via symlink

`~/.codex/config.toml` is intentionally **copied**, not symlinked, because Codex mutates its live config during normal TUI use.

## Repo layout

- `tmux/` — tmux config and helper scripts
- `pi/` — Pi-specific settings and extensions
- `codex/` — Codex config
- `skills/` — shared skills, with one repo source symlinked into agent-specific discovery locations like `~/.agents/skills` and `~/.claude/skills`

### Pi (coding agent)

```bash
~/.dotfiles/pi/install.sh
```

This symlinks:
- shared skills into `~/.agents/skills` (root `install.sh` also links them into `~/.claude/skills`)
- Pi extensions into `~/.pi/agent/extensions`
- Pi settings into `~/.pi/agent/settings.json`

Auth (`auth.json`) and sessions are machine-local and not synced.

#### `/draw` ASCII sketch modal

`/draw` opens a full-screen TUI canvas for quick diagrams you can paste into the prompt.

- Mouse: left drag draws, right drag erases
- Text mode: type characters directly onto the canvas
- Save: `Enter` (inserts a fenced `text` block into the editor)
- Cancel: `Esc`
- Toggle mode: `Ctrl+T` (or `Tab`)
- Undo/redo: `Ctrl+Z` / `Ctrl+Y`
- Clear: `Ctrl+X`
- Brush cycle (draw mode): `[` / `]` or mouse wheel
