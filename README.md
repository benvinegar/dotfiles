# Dotfiles

Personal configuration files, managed with symlinks.

## Setup on a new machine

```bash
git clone git@github.com:benvinegar/dotfiles.git ~/.dotfiles
```

### Pi (coding agent)

```bash
~/.dotfiles/pi/install.sh
```

This symlinks `extensions/` and `settings.json` into `~/.pi/agent/`.

Auth (`auth.json`) and sessions are machine-local and not synced.
