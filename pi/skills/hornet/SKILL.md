# Hornet Project

Hornet is the agent infrastructure layer. It has its own dedicated user and workspace on this machine.

## User & Access

- **User**: `hornet_agent` (uid 1001)
- **Home**: `/home/hornet_agent/`
- **Group**: `hornet_agent` — `bentlegen` is a member of this group
- **Repo**: `/home/hornet_agent/hornet/` (git@github.com:modem-dev/hornet.git)
- To access hornet_agent files, use `sg hornet_agent -c "..."` or `newgrp hornet_agent` (or re-login to pick up group)
- The `.pi/` and `.ssh/` dirs under hornet_agent are `drwx------` (agent-private, not group-readable)

> **Note**: `~/hornet_deprecated/` under bentlegen is the old stale workspace — do not use it.

## Structure

```
/home/hornet_agent/hornet/
├── README.md
├── SECURITY.md
├── setup.sh / start.sh
├── bin/                   # Operational scripts
├── pi/                    # Pi skills for the hornet agent sessions
│   └── skills/
│       ├── control-agent/
│       └── dev-agent/
└── slack-bridge/          # Slack ↔ pi control-agent bridge (Socket Mode)
```

Other repos checked out under `/home/hornet_agent/`:
- `modem/` — product app
- `website/` — marketing site

## Conventions

- New integrations get their own subdirectory (e.g. `/home/hornet_agent/hornet/discord-bridge/`)
- Pi extensions stay in `~/.pi/agent/extensions/` (loaded by pi automatically) but any supporting code or standalone services go in the hornet repo
- The hornet_agent pi sessions run under the `hornet_agent` user — check their status with `sg hornet_agent -c "..."`
