# Agent Instructions

## Filesystem Layout

| Location | What |
|----------|------|
| `~/Projects/` | All personal repos/checkouts |
| `~/Projects/dotfiles/` | Dotfiles repo (includes pi skills, extensions, settings) |
| `~/Projects/openclaw/` | OpenClaw — open-source personal AI assistant |
| `~/hornet_deprecated/` | **Old stale workspace — do not use** |

### Hornet Agent (separate user)

The production hornet agent runs under its own user. See `/skill hornet` for full details.

- **User**: `hornet_agent` — home at `/home/hornet_agent/`
- **Repos**: `~/workspace/modem/`, `~/workspace/website/` (under hornet_agent home)
- **Infra**: `/home/hornet_agent/hornet/` (agent infrastructure repo)
- **Access**: `bentlegen` is in the `hornet_agent` group with group write. Use `sudo -u hornet_agent bash -c "..."` to run commands.
- **⚠️ Do NOT use `Edit`/`Write` tools** on hornet_agent files — they create bentlegen-owned files. Always use `sudo -u hornet_agent tee` or `sudo -u hornet_agent bash -c`.

## Defaults

- When asked to change or fix something without specifying a project, ask which one.
- The **modem** app is at `/home/hornet_agent/workspace/modem`.
- The **hornet** infra repo is only at `/home/hornet_agent/hornet/` (no bentlegen copy — use `sudo -u hornet_agent` to access).
- The modem website repo is at `/home/hornet_agent/workspace/website`.
