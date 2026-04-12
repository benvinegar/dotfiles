# Dotfiles

Personal configuration files, managed with symlinks.

## Setup on a new machine

```bash
git clone git@github.com:benvinegar/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
./install.sh
```

On Arch Linux, there is also a convenience setup entrypoint for VMs and fresh Linux installs:

```bash
git clone git@github.com:benvinegar/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./arch/setup.sh
./install.sh
```

On macOS Apple Silicon, this repo also includes a reproducible native Arch Linux ARM Lima workflow:

```bash
~/.dotfiles/arch/lima/rebuild-vm.sh
~/.dotfiles/arch/lima/bootstrap-dotfiles.sh
```

That workflow builds a Lima-ready Arch Linux ARM image, recreates the VM, bootstraps dotfiles, and makes `limactl shell` open `zsh`.
See `arch/lima/README.md` for details and environment overrides.

`bootstrap.sh` installs terminal tools with the native package manager from one shared package list and bootstraps Zsh core dependencies:
- macOS: Homebrew via `brew install`
- Arch Linux: `pacman` when the shared package names exist in the current repos
- source of truth for terminal tools: `packages/common.txt`
- for fresh Arch machines and VMs, prefer `./arch/setup.sh`, which also filters unavailable packages
- clones Oh My Zsh core if missing via `zsh/bootstrap.sh`

`install.sh` manages:
- `~/.tmux.conf` via symlink
- tmux helper scripts into `~/bin/` via symlink
- `~/.codex/config.toml` via copy
- `~/.config/dotfiles/shell` via symlink
- `~/.config/dotfiles/oh-my-zsh-custom` via symlink
- `~/.config/dotfiles/zsh/oh-my-zsh.zsh` via symlink
- `~/.config/eza/theme.yml` via symlink
- `~/.p10k.zsh` via symlink
- managed shell/Oh My Zsh/p10k blocks in `~/.bashrc` and `~/.zshrc`
- shared agent skills into `~/.agents/skills` via symlink
- shared agent skills into `~/.claude/skills` via symlink

`~/.codex/config.toml` is intentionally **copied**, not symlinked, because Codex mutates its live config during normal TUI use.

## Repo layout

- `arch/` — Arch Linux convenience setup entrypoints for fresh VMs and installs, including `arch/lima/` for native Arch Linux ARM on Lima
- `tmux/` — tmux config and helper scripts
- `shell/` — shared shell snippets and aliases sourced from `~/.bashrc` / `~/.zshrc`
- `zsh/` — Zsh-specific bootstrap and prompt wiring files such as `p10k.zsh` and `oh-my-zsh.zsh`
- `oh-my-zsh-custom/` — repo-managed Oh My Zsh custom themes/plugins used by installed `~/.zshrc`
- `eza/` — shared `eza` theme config
- `packages/` — shared package lists used by `bootstrap.sh` and `arch/setup.sh`
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
- `fresh`
- `shellcheck`
- `shfmt`

`packages/common.txt` is the shared source of truth, but not every entry is guaranteed to exist in every package manager or repo.
For example, `fresh` is available via Homebrew but not in the default Arch repos.

For Arch-specific machine setup, prefer `./arch/setup.sh`, which installs both:
- `packages/common.txt`
- `packages/arch-extra.txt`
- filters the combined package list against the current Arch repos
- skips unavailable packages instead of failing hard
- switches the login shell to `zsh` when available
- configures npm global installs to use `~/.local`

If package names diverge further over time, add a small platform mapping layer instead of duplicating the whole list.

`packages/arch-extra.txt` currently adds:
- `git`
- `zsh`
- `openssh`
- `curl`
- `rsync`
- `unzip`
- `zip`
- `base-devel`
- `github-cli`
- `nodejs`
- `npm`
- `ttf-cascadia-mono-nerd`

Use a dry run to preview what would be installed:

```bash
./bootstrap.sh --dry-run
./arch/setup.sh --dry-run
```

Lint or format the managed shell scripts with:

```bash
./scripts/lint-shell.sh
./scripts/format-shell.sh
```

For unattended Arch installs, pass `--noconfirm`:

```bash
./arch/setup.sh --noconfirm
```

## Shell utilities

Shared shell snippets live in `shell/` and are sourced from both Bash and Zsh via `~/.config/dotfiles/shell/init.sh`.

## Zsh prompt

`bootstrap.sh` runs `zsh/bootstrap.sh`, which:
- clones Oh My Zsh core if missing
- does not clone repo-managed themes/plugins

Repo-managed Zsh sources of truth are:
- `zsh/oh-my-zsh.zsh` — portable Oh My Zsh load block
- `oh-my-zsh-custom/` — vendored custom themes/plugins
- `zsh/p10k.zsh` — Powerlevel10k config

`install.sh` wires `~/.zshrc` to source `zsh/oh-my-zsh.zsh` and `~/.p10k.zsh` via managed marker blocks, rather than installing a full repo-managed `~/.zshrc`.

Font expectation:
- terminal configs in this repo expect `CaskaydiaMono Nerd Font`
- Arch package: `ttf-cascadia-mono-nerd`
- macOS: install a compatible Caskaydia/Cascadia Nerd Font or adjust terminal font settings

Current defaults:
- `zsh` is the expected interactive shell on Arch setups bootstrapped with `./arch/setup.sh`
- npm global installs land under `~/.local` so `npm i -g ...` works without `sudo`
- `~/.local/bin`, `~/bin`, and `~/.bun/bin` are restored onto `PATH`
- `EDITOR` / `VISUAL` default to `fresh` when the binary is installed
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

Dotfiles wrap interactive `eza` so `theme.yml` wins even if your shell sets `LS_COLORS` or `EZA_COLORS`.
Use `command eza ...` if you ever want the raw upstream behavior.

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
