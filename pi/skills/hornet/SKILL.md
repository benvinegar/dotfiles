# Hornet Project

All agent-related code lives in `~/hornet/`. When creating new agent tools, extensions, bridges, or integrations, put them there.

## Structure

```
~/hornet/
├── slack-bridge/      # Slack ↔ pi control-agent bridge (Socket Mode)
```

## Conventions

- New integrations get their own subdirectory (e.g. `~/hornet/discord-bridge/`)
- Pi extensions stay in `~/.pi/agent/extensions/` (loaded by pi automatically) but any supporting code or standalone services go in `~/hornet/`
- Use `~/hornet/README.md` for high-level project docs
