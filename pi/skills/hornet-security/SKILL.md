---
name: hornet-security
description: Hornet security hardening — vulnerabilities, implementation plan, and OpenClaw reference patterns.
---

# Hornet Security Hardening

> Use this skill when working on hornet security todos. Start by running `todo list` to see open items.

## Context

Hornet is the agent infrastructure at `~/hornet/`. It has a Slack bridge (`slack-bridge/bridge.mjs`) that connects Slack to pi agent sessions via Unix domain sockets. Three cooperating sessions: slack-bridge process → control-agent (pi) → dev-agent (pi).

**Reference project:** OpenClaw (`~/Projects/openclaw/`) — a mature open-source personal AI assistant. Its `src/security/` directory has production-grade implementations of many things hornet needs. Specifically:
- `src/security/external-content.ts` — external content wrapping with boundary markers, Unicode homoglyph sanitization, suspicious pattern detection (12 regex patterns), typed source labels
- `src/security/audit.ts` — full `openclaw security audit` CLI: filesystem permission checks, gateway auth checks, rate limit config, tailscale exposure, browser control auth, logging redaction, elevated exec allowlists, tool policy, trusted proxy validation, secrets-in-config scanning
- `src/security/secret-equal.ts` — constant-time secret comparison
- `src/security/dangerous-tools.ts` — HTTP tool deny list
- `src/security/skill-scanner.ts` — static analysis of installed skills for safety
- `src/security/fix.ts` — auto-fix for audit findings (chmod, etc.)
- `src/gateway/auth.ts` — multi-mode gateway auth (token, password, trusted-proxy, tailscale), rate limiting, IP resolution, local-direct detection

**The `openclaw-checkout` skill file (`~/.pi/agent/skills/openclaw-checkout/SKILL.md`) documents MODEM's Stripe billing, NOT OpenClaw.** It should be renamed/rewritten if you need a Modem billing skill, or deleted and replaced with a proper OpenClaw skill.

## Current State (as of 2026-02-15)

**All previous security todos were marked "done" but NONE were implemented.** Verified by checking:
- No `bin/` directory exists in `~/hornet/`
- No `detectSuspiciousPatterns()` or `wrapExternalContent()` in `bridge.mjs`  
- No `SECURITY.md` in hornet root
- `.env` is still mode `644`
- No iptables/firewall rules
- Zero git commits for any security work

## Key Files

| File | What |
|------|------|
| `~/hornet/slack-bridge/bridge.mjs` | Single-file Slack bridge (~300 lines, plain ESM JS) |
| `~/hornet/slack-bridge/.env` | Slack tokens + pi session UUID (**currently 644, should be 600**) |
| `~/.pi/agent/skills/control-agent/SKILL.md` | Control agent behavior (has email auth via HORNET_SECRET) |
| `~/.pi/agent/skills/dev-agent/SKILL.md` | Dev agent behavior (works in git worktrees) |
| `~/Projects/openclaw/src/security/` | **Reference implementations** — borrow patterns from here |

## Top Vulnerabilities (priority order)

1. **`.env` is world-readable (644)** — contains `xoxb-`, `xapp-` tokens
2. **`SLACK_ALLOWED_USERS` defaults to open** — empty list = anyone in workspace can talk to agent
3. **No prompt injection defense** — untrusted Slack messages go straight to LLM without wrapping or detection
4. **No rate limiting** — allowed users can flood the agent
5. **No input validation on bridge API** — `/send` and `/react` don't type-check params
6. **Session logs/sockets are group-readable** — `~/.pi/` tree is permissive
7. **No monitoring** — console.log only, no alerting

## Implementation Notes

- `bridge.mjs` is a single file — keep it that way, all changes go there
- No build step, no TypeScript — plain ESM JavaScript
- Only 2 dependencies: `@slack/bolt` and `dotenv`
- `hornet/` is NOT a git repo itself — `modem/` and `website/` are submodules with their own `.git`
- OpenClaw's `external-content.ts` is the gold standard for content wrapping — port the pattern to JS for bridge.mjs

## Todo Priority

Run `todo list` — items are tagged `security` + `hornet`. Do them in this order:

1. `chmod 600 .env` (30 sec)
2. Make SLACK_ALLOWED_USERS required / fail-closed (5 min)
3. Wrap external content with security boundary markers — use OpenClaw's `wrapExternalContent()` pattern (30 min)
4. Add prompt injection detection logging — use OpenClaw's `SUSPICIOUS_PATTERNS` regex list (20 min)
5. Rate limiting per user (15 min)
6. Validate bridge API JSON params (15 min)
7. Harden filesystem permissions script (15 min)
8. Trust boundaries doc (30 min)
9. Security audit script — study OpenClaw's `runSecurityAudit()` for structure (1 hr)
10. Outbound network firewall (30 min)
