# Dotfiles

Personal configuration files, managed with symlinks.

## Setup on a new machine

```bash
git clone git@github.com:benvinegar/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
./install.sh
```

`bootstrap.sh` installs terminal tools with the native package manager from one shared package list and bootstraps Zsh prompt dependencies:
- macOS: Homebrew via `brew install`
- Arch Linux: `pacman`
- source of truth for terminal tools: `packages/common.txt`
- clones Oh My Zsh + Powerlevel10k if missing via `zsh/bootstrap.sh`

`install.sh` manages:
- `~/.tmux.conf` via symlink
- tmux helper scripts into `~/bin/` via symlink
- `~/.codex/config.toml` via copy
- `~/.config/dotfiles/shell` via symlink
- `~/.config/eza/theme.yml` via symlink
- `~/.p10k.zsh` via symlink
- shell init blocks in `~/.bashrc` and `~/.zshrc`
- shared agent skills into `~/.agents/skills` via symlink
- shared agent skills into `~/.claude/skills` via symlink

`~/.codex/config.toml` is intentionally **copied**, not symlinked, because Codex mutates its live config during normal TUI use.

## Repo layout

- `tmux/` — tmux config and helper scripts
- `shell/` — shared shell snippets and aliases sourced from `~/.bashrc` / `~/.zshrc`
- `zsh/` — Zsh-specific prompt config and bootstrap scripts for Oh My Zsh / Powerlevel10k
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

## Zsh prompt

`bootstrap.sh` runs `zsh/bootstrap.sh`, which:
- clones Oh My Zsh if missing
- clones Powerlevel10k if missing
- seeds `~/.zshrc` from the Oh My Zsh template on fresh machines

Powerlevel10k is kept as a repo-managed file at `zsh/p10k.zsh` and installed to `~/.p10k.zsh`.
If `~/.zshrc` does not already source `~/.p10k.zsh`, `install.sh` adds a small source block.

Font expectation:
- terminal configs in this repo expect `CaskaydiaMono Nerd Font`
- Arch package: `ttf-cascadia-mono-nerd`
- macOS: install a compatible Caskaydia/Cascadia Nerd Font or adjust terminal font settings

Current defaults:
- `~/.local/bin`, `~/bin`, and `~/.bun/bin` are restored onto `PATH`
- `nvm` is loaded if present so npm globals from your active nvm Node stay available
- `ls` → `eza --group-directories-first --icons=auto`
- `l`, `la`, `ll`, and `lt` helper aliases
- `EZA_CONFIG_DIR=$HOME/.config/eza` so Linux and macOS use the same theme path
- `~/.config/eza/theme.yml` points at the repo-managed Tokyo Night theme from `eza-community/eza-themes`
- `cd` → `zd`, a zoxide-backed wrapper that still handles plain paths and `cd` with no args
- `ff` → `fzf` with `bat` preview
- `Ctrl-R` → `fzf` history search in Bash and Zsh
- `compress` / `decompress` tar helpers

Install `eza` via `./bootstrap.sh` as part of the managed package set.

Note: `LS_COLORS` / `EZA_COLORS` override the YAML theme file if you set them elsewhere.

### Pi (coding agent)

```bash
~/.dotfiles/pi/install.sh
```

This symlinks:
- shared skills into `~/.agents/skills` (root `install.sh` also links them into `~/.claude/skills`)
- Pi extensions into `~/.pi/agent/extensions`
- Pi themes into `~/.pi/agent/themes`
- Pi settings into `~/.pi/agent/settings.json`

Current Pi theme defaults include:
- `theme: "tokyonight"`
- canonical theme file: `pi/themes/tokyonight.json`

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
