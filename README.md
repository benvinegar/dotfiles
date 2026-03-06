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

### Pi (coding agent)

```bash
~/.dotfiles/pi/install.sh
```

This symlinks `extensions/`, `skills/`, and `settings.json` into `~/.pi/agent/`.

Auth (`auth.json`) and sessions are machine-local and not synced.
