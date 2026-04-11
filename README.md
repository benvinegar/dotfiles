# Dotfiles

Personal configuration files, managed with symlinks.

## Setup on a new machine

```bash
git clone git@github.com:benvinegar/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
./install.sh
```

`bootstrap.sh` installs terminal tools with the native package manager from one shared package list:
- macOS: Homebrew via `brew install`
- Arch Linux: `pacman`
- source of truth: `packages/common.txt`

`install.sh` manages:
- `~/.tmux.conf` via symlink
- tmux helper scripts into `~/bin/` via symlink
- `~/.codex/config.toml` via copy
- `~/.config/dotfiles/shell` via symlink
- `~/.config/eza/theme.yml` via symlink
- shell init blocks in `~/.bashrc` and `~/.zshrc`
- shared agent skills into `~/.agents/skills` via symlink
- shared agent skills into `~/.claude/skills` via symlink

`~/.codex/config.toml` is intentionally **copied**, not symlinked, because Codex mutates its live config during normal TUI use.

## Repo layout

- `tmux/` — tmux config and helper scripts
- `shell/` — shared shell snippets and aliases sourced from `~/.bashrc` / `~/.zshrc`
- `eza/` — shared `eza` theme config
- `packages/` — shared package lists used by `bootstrap.sh`
- `pi/` — Pi-specific settings and extensions
- `codex/` — Codex config
- `skills/` — shared skills, with one repo source symlinked into agent-specific discovery locations like `~/.agents/skills` and `~/.claude/skills`

## Package bootstrap

`bootstrap.sh` is intentionally separate from `install.sh`:
- `bootstrap.sh` installs packages
- `install.sh` links config files and shell snippets

Current managed terminal tools live in `packages/common.txt`:
- `eza`
- `tmux`
- `bat`
- `fd`
- `ripgrep`
- `zoxide`
- `fzf`
- `jq`

Right now these package names match on both Homebrew and Arch, so one plain-text list is enough.
If they ever diverge, add a small platform mapping layer instead of duplicating the whole list.

Use a dry run to preview what would be installed:

```bash
./bootstrap.sh --dry-run
```

## Shell utilities

Shared shell snippets live in `shell/` and are sourced from both Bash and Zsh via `~/.config/dotfiles/shell/init.sh`.

Current defaults:
- `ls` → `eza --group-directories-first --icons=auto`
- `l`, `la`, `ll`, and `lt` helper aliases
- `EZA_CONFIG_DIR=$HOME/.config/eza` so Linux and macOS use the same theme path
- `~/.config/eza/theme.yml` points at the repo-managed Tokyo Night theme from `eza-community/eza-themes`

Install `eza` via `./bootstrap.sh` as part of the managed package set.

Note: `LS_COLORS` / `EZA_COLORS` override the YAML theme file if you set them elsewhere.

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
