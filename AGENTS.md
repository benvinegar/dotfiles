# AGENTS.md

Guidance for agents working in this dotfiles repo.

## Purpose

Maintain a small, understandable, symlink-based dotfiles repo that is:
- portable across **macOS and Linux**
- free of **private data** and **machine-specific state**
- easy to reinstall from scratch
- easy for a fresh agent to understand quickly

## Repo shape

This repo is organized by tool, with source files that get symlinked into real runtime locations.

Current top-level areas:
- `tmux/`
- `pi/`
- `codex/`
- `skills/`

`skills/` is the single repo source of truth for shared skills; installers may symlink it into multiple agent-specific discovery locations.

Important entrypoints:
- `install.sh`
- `pi/install.sh`
- `README.md`

When changing layout, update installers and docs in the same change.

## Core rules

### 1) Keep it portable
- Prefer behavior that works on both macOS and Linux.
- Prefer POSIX-ish shell where practical.
- If a command is platform-specific, add a fallback or gate it clearly.
- Prefer `$HOME` in shell scripts over hardcoded home paths.

### 2) Keep private and local state out of git
- Never commit secrets, keys, tokens, cookies, auth files, or certificates.
- Never commit machine-local runtime state: sessions, sockets, caches, logs, ephemeral files.
- Avoid machine-specific paths such as `/home/<user>/...` or `/Users/<user>/...`.
- Avoid committing personal trusted-project lists or local repo paths.

### 3) Prefer simple, explicit install flows
- Keep installers idempotent and safe to rerun.
- Prefer explicit symlink logic over clever or hidden automation.
- Preserve backup behavior when replacing existing files.
- If a file is managed by the repo, wire it into the relevant installer.

### 4) Prefer boring structure over clever structure
- Keep files grouped by tool/topic.
- Keep reusable config separate from ephemeral state.
- Do not add layout indirection unless it clearly simplifies maintenance.
- Prefer one obvious source of truth for each managed config.

## Working style

When making changes:
1. understand the install path and runtime target
2. make the smallest coherent change
3. update install scripts if needed
4. update `README.md` if behavior or layout changed
5. check the diff for secrets, absolute paths, and accidental machine-specific state

## Validation

Run the smallest relevant validation set.

Common checks:
- `./install.sh`
- `./pi/install.sh`
- `tmux source-file ~/.tmux.conf` for tmux changes
- inspect installed symlinks if layout changed
- inspect `git diff` before committing

Useful audits:
- search for personal paths: `rg -n '/home/|/Users/' .`
- search for obvious secrets: `rg -n 'api[_-]?key|token|secret|password' .`

## Design preferences

Borrow the good parts from well-maintained dotfile repos:
- topic-oriented organization
- explicit install entrypoints
- safe reruns
- clear README/docs
- local overrides and machine state kept out of the shared repo

When in doubt, choose the option that is more:
- portable
- explicit
- reversible
- boring

## Commits

Prefer concise Conventional Commit titles, e.g.:
- `refactor(dotfiles): organize repo by tool`
- `feat(tmux): add agent overview popup`
- `chore: remove machine-specific paths`
