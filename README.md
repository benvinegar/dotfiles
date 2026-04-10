# Dotfiles

Personal configuration files, managed with symlinks.

## Setup on a new machine

```bash
git clone git@github.com:benvinegar/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

`install.sh` links:
- `~/.tmux.conf`
- tmux helper scripts into `~/bin/`
- `~/.codex/config.toml`
- shared agent skills into `~/.agents/skills`

## Agent layout

- `agents/skills/` — shared skills for any agent that supports the common `~/.agents/skills` convention
- `agents/pi/extensions/` — Pi-specific extensions
- `agents/pi/skills -> ../skills` — Pi-side symlink back to the shared skill set
- `pi -> agents/pi` — compatibility symlink for older paths

### Pi (coding agent)

```bash
~/.dotfiles/agents/pi/install.sh
```

This symlinks:
- shared skills into `~/.agents/skills`
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
