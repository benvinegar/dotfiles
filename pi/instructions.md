# Agent Instructions

## Filesystem Layout

| Location | What |
|----------|------|
| `~/Projects/` | All personal repos/checkouts |
| `~/Projects/dotfiles/` | Dotfiles repo (includes pi skills, extensions, settings) |
| `~/Projects/hornet/` | Hornet repo checkout (bentlegen's copy) |
| `~/Projects/openclaw/` | OpenClaw — open-source personal AI assistant |
| `~/hornet_deprecated/` | **Old stale workspace — do not use** |

### Hornet Agent (separate user)

The production hornet agent runs under its own user. See `/skill hornet` for full details.

- **User**: `hornet_agent` — home at `/home/hornet_agent/`
- **Repos**: `/home/hornet_agent/hornet/`, `modem/`, `website/`
- **Access**: `bentlegen` is in the `hornet_agent` group. Use `sg hornet_agent -c "..."` to access.

## Defaults

- When asked to change or fix something without specifying a project, ask which one.
- The **modem** app is at `/home/hornet_agent/modem` (or `~/Projects/hornet/` for the hornet infra itself).
- The modem website repo is at `/home/hornet_agent/website`.
