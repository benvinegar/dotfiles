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
- The `.pi/` and `.ssh/` dirs under hornet_agent are `drwx------` (agent-private, not group-readable)

> **Note**: `~/hornet_deprecated/` under bentlegen is the old stale workspace — do not use it.

### ⚠️ File Ownership — IMPORTANT

You are running as `bentlegen`. **Do NOT use `Edit` or `Write` tools directly on hornet_agent files** — they will create bentlegen-owned files in hornet_agent's repo, causing mixed ownership and breaking git operations.

Instead, always write to hornet_agent files via:
```bash
# For small edits:
sudo -u hornet_agent tee /path/to/file > /dev/null << 'EOF'
content here
EOF

# For commands:
sudo -u hornet_agent bash -c '...'
```

If you accidentally create bentlegen-owned files, fix with:
```bash
find /home/hornet_agent/hornet -user bentlegen -exec chmod g+rwX {} +
```

### Access Patterns

```bash
# Run commands as hornet_agent
sudo -u hornet_agent bash -c '...'

# Git commands
sudo -u hornet_agent bash -c 'cd ~/hornet && git ...'

# Group-based access (alternative, less reliable)
sg hornet_agent -c "..."
```

Git repos use `core.sharedRepository = group` so new objects get group-write perms regardless of umask.

## Structure

```
/home/hornet_agent/
├── hornet/                  ← agent infra repo (git@github.com:modem-dev/hornet.git)
│   ├── README.md
│   ├── SECURITY.md          ← 🔒 protected
│   ├── setup.sh             ← 🔒 protected (creates user, installs deps, firewall, etc.)
│   ├── start.sh             ← 🔒 protected (launches control-agent)
│   ├── hooks/
│   │   └── pre-commit       ← 🔒 protected (blocks agent from modifying security files)
│   ├── bin/                 ← 🔒 ALL protected (security scripts)
│   │   ├── security-audit.sh
│   │   ├── scan-extensions.mjs
│   │   ├── harden-permissions.sh
│   │   ├── setup-firewall.sh
│   │   ├── hornet-docker
│   │   ├── hornet-safe-bash
│   │   └── redact-logs.sh
│   ├── pi/
│   │   ├── extensions/
│   │   │   ├── tool-guard.ts       ← 🔒 protected
│   │   │   ├── tool-guard.test.mjs ← 🔒 protected
│   │   │   ├── auto-name.ts        ← agent-modifiable
│   │   │   ├── zen-provider.ts     ← agent-modifiable
│   │   │   ├── sentry-monitor.ts   ← agent-modifiable
│   │   │   └── ...
│   │   └── skills/                  ← agent-modifiable (operational knowledge)
│   │       ├── control-agent/
│   │       ├── dev-agent/
│   │       └── sentry-agent/
│   └── slack-bridge/
│       ├── bridge.mjs               ← agent-modifiable
│       ├── security.mjs             ← 🔒 protected
│       └── security.test.mjs        ← 🔒 protected
├── workspace/
│   ├── modem/               ← product app repo
│   ├── website/             ← marketing site repo
│   └── worktrees/           ← all git worktrees land here
└── scripts/                 ← agent-authored operational scripts (separate git repo)
```

🔒 = protected by root-owned pre-commit hook + tool-guard rules. Agent cannot modify.
The hook source is in `hooks/pre-commit`, installed to `.git/hooks/pre-commit` by `setup.sh` as root-owned.

## Self-Modification Guardrails

3-layer defense prevents the agent from weakening its own security:

| Layer | What | Bypass |
|-------|------|--------|
| **Pre-commit hook** | Blocks `git commit` of protected files | `--no-verify` (requires root ownership of hook to prevent agent bypass) |
| **Tool-guard rules** | Blocks `write`/`edit` tool calls to protected paths before they hit disk | None (compiled into extension) |
| **Skill guidance** | Skills document what is/isn't modifiable | Soft — relies on LLM compliance |

**Protected files**: `bin/`, `hooks/`, `setup.sh`, `start.sh`, `SECURITY.md`, `tool-guard.ts`, `security.mjs` (and their tests).

**Hook ownership**: Must be root-owned to be tamper-proof:
```bash
sudo chown root:root /home/hornet_agent/hornet/.git/hooks/pre-commit
```

## Security Stack

Hornet's security is layered defense-in-depth:

| Layer | What | File |
|-------|------|------|
| **Self-modification guard** | Pre-commit hook + tool-guard rules block agent from editing security files | `hooks/pre-commit`, `tool-guard.ts` |
| **Content wrapping** | External messages wrapped with security boundaries + Unicode homoglyph sanitization | `security.mjs` |
| **Prompt injection detection** | 12 regex patterns, log-only | `security.mjs` |
| **Tool call interception** | Pi extension blocks dangerous bash/write/edit before execution | `tool-guard.ts` |
| **Shell command deny list** | Bash wrapper blocks rm -rf, curl\|bash, reverse shells, fork bombs | `hornet-safe-bash` |
| **Access control** | SLACK_ALLOWED_USERS fail-closed (bridge exits if empty) | `bridge.mjs` |
| **Rate limiting** | Per-user 5/min on Slack, 30/min on bridge API | `security.mjs` |
| **Timing-safe auth** | `crypto.timingSafeEqual` for secret comparison | `security.mjs` |
| **API validation** | Type + format checking on bridge API params | `security.mjs` |
| **Filesystem hardening** | 700 dirs, 600 secrets, runs on every boot | `harden-permissions.sh` |
| **Network firewall** | iptables per-UID egress, allow 80/443/22/53 only + localhost restricted | `setup-firewall.sh` |
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
- Git repos use `core.sharedRepository = group` — never change this
- Agent commits its own operational learnings to skills; admin commits security changes with `--no-verify`

## Running Tests

```bash
# All tests
sudo -u hornet_agent bash -c "export PATH=~/opt/node-v22.14.0-linux-x64/bin:\$PATH && \
  cd ~/hornet/slack-bridge && node --test security.test.mjs && \
  cd ~/hornet/pi/extensions && node --test tool-guard.test.mjs && \
  cd ~/hornet/bin && node --test scan-extensions.test.mjs && \
  bash hornet-safe-bash.test.sh && bash redact-logs.test.sh && bash security-audit.test.sh"

# Just bridge security
sudo -u hornet_agent bash -c "export PATH=~/opt/node-v22.14.0-linux-x64/bin:\$PATH && \
  cd ~/hornet/slack-bridge && npm test"

# Security audit (live)
sudo -u hornet_agent bash -c "cd ~/hornet && bash bin/security-audit.sh --deep"
```
