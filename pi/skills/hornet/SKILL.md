---
name: hornet
description: Hornet agent infrastructure — project layout, security stack, conventions, and how to run tests.
---

# Hornet Project

Hornet is the agent infrastructure layer. It has its own dedicated user and workspace on this machine.

## User & Access

- **User**: `hornet_agent` (uid 1001)
- **Home**: `/home/hornet_agent/`
- **Group**: `hornet_agent` — `bentlegen` is a member with **group write** on the repo
- **Repo**: `/home/hornet_agent/hornet/` (git@github.com:modem-dev/hornet.git)
- To access hornet_agent files, use `sg hornet_agent -c "..."`
- Git commands need: `git -c safe.directory=/home/hornet_agent/hornet` and `export HOME=/home/hornet_agent`
- The `.pi/` and `.ssh/` dirs under hornet_agent are `drwx------` (agent-private, not group-readable)

> **Note**: `~/hornet_deprecated/` under bentlegen is the old stale workspace — do not use it.

## Structure

```
/home/hornet_agent/hornet/
├── README.md
├── SECURITY.md
├── setup.sh                # Full install script (creates user, installs deps, firewall, etc.)
├── start.sh                # Launches control-agent (hardens perms, redacts logs, starts pi)
├── bin/
│   ├── security-audit.sh   # 24-check security audit (--deep for cross-pattern scan)
│   ├── security-audit.test.sh  # 21 tests
│   ├── scan-extensions.mjs # Node.js cross-pattern static analysis scanner
│   ├── scan-extensions.test.mjs # 15 tests
│   ├── harden-permissions.sh   # chmod 700/600 on pi state, secrets, logs
│   ├── setup-firewall.sh       # iptables per-UID egress control
│   ├── hornet-firewall.service # systemd unit for firewall persistence
│   ├── hornet-docker           # Docker wrapper (blocks --privileged, host mounts)
│   ├── hornet-safe-bash        # Bash wrapper (blocks rm -rf /, curl|bash, reverse shells)
│   ├── hornet-safe-bash.test.sh # 24 tests
│   ├── redact-logs.sh          # Secret scrubber for session logs
│   └── redact-logs.test.sh     # 11 tests
├── pi/
│   ├── extensions/
│   │   ├── tool-guard.ts       # Pi extension: intercepts dangerous tool calls before execution
│   │   ├── tool-guard.test.mjs # 60 tests
│   │   ├── auto-name.ts
│   │   ├── context.ts
│   │   ├── control.ts
│   │   ├── files.ts
│   │   ├── loop.ts
│   │   ├── todos.ts
│   │   ├── zen-provider.ts
│   │   ├── agentmail/
│   │   ├── email-monitor/
│   │   └── kernel/
│   └── skills/
│       ├── control-agent/
│       └── dev-agent/
└── slack-bridge/
    ├── bridge.mjs              # Slack ↔ pi bridge (Socket Mode, fail-closed, rate-limited)
    ├── security.mjs            # Pure security functions (extracted for testability)
    ├── security.test.mjs       # 71 tests
    └── package.json
```

Other repos checked out under `/home/hornet_agent/`:
- `modem/` — product app
- `website/` — marketing site

## Security Stack

Hornet's security is layered defense-in-depth:

| Layer | What | File |
|-------|------|------|
| **Content wrapping** | External messages wrapped with security boundaries + Unicode homoglyph sanitization | `security.mjs` |
| **Prompt injection detection** | 12 regex patterns, log-only | `security.mjs` |
| **Tool call interception** | Pi extension blocks dangerous bash/write/edit before execution | `tool-guard.ts` |
| **Shell command deny list** | Bash wrapper blocks rm -rf, curl\|bash, reverse shells, fork bombs | `hornet-safe-bash` |
| **Access control** | SLACK_ALLOWED_USERS fail-closed (bridge exits if empty) | `bridge.mjs` |
| **Rate limiting** | Per-user 5/min on Slack, 30/min on bridge API | `security.mjs` |
| **Timing-safe auth** | `crypto.timingSafeEqual` for secret comparison | `security.mjs` |
| **API validation** | Type + format checking on bridge API params | `security.mjs` |
| **Filesystem hardening** | 700 dirs, 600 secrets, runs on every boot | `harden-permissions.sh` |
| **Network firewall** | iptables per-UID egress, allow 80/443/22/53 only + localhost restricted to bridge (7890), Ollama (11434), DNS (53) | `setup-firewall.sh` |
| **Docker isolation** | Wrapper blocks --privileged, host mounts, socket mounts | `hornet-docker` |
| **Security audit** | 24 checks, `--deep` for cross-pattern extension scanning | `security-audit.sh` |
| **Extension scanning** | Cross-pattern static analysis (exfiltration, obfuscation, crypto-mining) | `scan-extensions.mjs` |
| **Secret scanning** | Scans files, git history, session logs for leaked tokens | `security-audit.sh` |
| **Log redaction** | Scrubs API keys, tokens, private keys from session logs on boot | `redact-logs.sh` |
| **Process isolation** | `/proc` mounted with `hidepid=2` — hornet_agent can only see its own processes | `setup.sh` |

**Tests: 202 total** across 6 test files, all passing.

## Conventions

- New integrations get their own subdirectory (e.g. `/home/hornet_agent/hornet/discord-bridge/`)
- Pi extensions are symlinked from `hornet/pi/extensions/` → `~/.pi/agent/extensions/`
- Security functions are extracted into testable pure-function modules (no side effects, no env vars)
- All security code must have tests before merging
- Run `security-audit.sh --deep` after any security-relevant changes

## Running Tests

```bash
# All tests
sg hornet_agent -c "export PATH=/home/hornet_agent/opt/node-v22.14.0-linux-x64/bin:\$PATH && \
  cd /home/hornet_agent/hornet/slack-bridge && node --test security.test.mjs && \
  cd /home/hornet_agent/hornet/pi/extensions && node --test tool-guard.test.mjs && \
  cd /home/hornet_agent/hornet/bin && node --test scan-extensions.test.mjs && \
  bash hornet-safe-bash.test.sh && bash redact-logs.test.sh && bash security-audit.test.sh"

# Just bridge security
sg hornet_agent -c "export PATH=...:\$PATH && cd /home/hornet_agent/hornet/slack-bridge && npm test"

# Security audit (live)
sg hornet_agent -c "cd /home/hornet_agent/hornet && bash bin/security-audit.sh --deep"
```
