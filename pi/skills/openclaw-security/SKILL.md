---
name: openclaw-security
description: Security assessment of the OpenClaw personal AI assistant (~/Projects/openclaw). Use when comparing OpenClaw's security posture to our own projects (Hornet, Modem).
---

# OpenClaw Security Assessment

> **Repo**: `~/Projects/openclaw/` (github.com/openclaw/openclaw, MIT license)
> **What it is**: A personal AI assistant you self-host. It connects to messaging channels (WhatsApp, Telegram, Slack, Discord, Signal, iMessage, etc.), runs a Gateway server, and gives the LLM access to tools (shell exec, file I/O, browser control, etc.).
> **Why we care**: OpenClaw is the most mature open-source project in this space. Its security posture is a benchmark for comparing our own agent infrastructure (Hornet + Modem).

---

## Security Surface Summary

OpenClaw's security code lives in **`src/security/`** (~8,100 lines across 22 files) plus **`src/gateway/auth.ts`** and supporting modules. It also has extensive docs at `docs/gateway/security/`.

### 1. Prompt Injection Defense (`src/security/external-content.ts`, 299 lines)

**What it does:**
- Wraps all untrusted external content (email, webhooks, browser, web search/fetch, channel metadata) with security boundary markers (`<<<EXTERNAL_UNTRUSTED_CONTENT>>>`)
- Prepends a security warning instructing the LLM to ignore embedded instructions
- Detects suspicious patterns (12 regex rules) for monitoring — logs but doesn't block
- Sanitizes Unicode homoglyph attacks that try to spoof boundary markers (fullwidth ASCII, CJK angle brackets, mathematical brackets)
- Typed source labels: `email`, `webhook`, `api`, `browser`, `channel_metadata`, `web_search`, `web_fetch`

**Key patterns:**
- `wrapExternalContent()` — the core wrapper, used everywhere untrusted content enters the system
- `detectSuspiciousPatterns()` — regex-based injection detection (monitoring, not blocking)
- `buildSafeExternalPrompt()` — combines wrapping with job context (task name, ID, timestamp)
- `wrapWebContent()` — lighter wrapper for web search results
- `buildUntrustedChannelMetadata()` — wraps channel names/topics/descriptions (in `channel-metadata.ts`)

**Strengths:**
- Defense-in-depth: marker sanitization prevents attackers from closing the boundary early
- Consistent application across all external content sources
- Unicode-aware — not just ASCII pattern matching

**Limitations:**
- Relies on LLM compliance with the security notice — not a hard boundary
- Detection patterns are regex-based, not ML-based — sophisticated injections may evade
- Logs suspicious patterns but doesn't block (design choice for usability)

### 2. Gateway Authentication (`src/gateway/auth.ts`, ~350 lines)

**Multi-mode auth system:**

| Mode | How it works |
|------|-------------|
| `token` | Shared secret token (recommended). Constant-time comparison via `safeEqualSecret()` |
| `password` | Shared password. Same constant-time comparison |
| `tailscale` | Tailscale Serve identity headers + whois verification against Tailscale API |
| `trusted-proxy` | Delegates to reverse proxy (Pomerium, Caddy, nginx). Validates source IP against `trustedProxies` list, extracts user from configurable header, optional user allowlist |
| `none` | No auth (only safe on loopback) |

**Key security properties:**
- **Constant-time secret comparison** (`src/security/secret-equal.ts`) — prevents timing attacks
- **Tailscale whois verification** — doesn't trust headers alone; verifies via Tailscale API that the claimed user matches the source IP
- **Local-direct detection** (`isLocalDirectRequest()`) — only trusts loopback + localhost Host header + no proxy headers (unless from trusted proxy)
- **Trusted proxy validation** — requires explicit IP allowlist; rejects proxy headers from untrusted sources

### 3. Rate Limiting (`src/gateway/auth-rate-limit.ts`, ~230 lines)

**In-memory sliding-window rate limiter:**
- Tracks failed auth attempts per `{scope, clientIp}`
- Separate scopes for shared-secret auth vs device-token auth
- Configurable: `maxAttempts` (default 10), `windowMs` (default 60s), `lockoutMs` (default 5min)
- Loopback addresses exempt by default (prevents local CLI lockout)
- Periodic pruning to prevent unbounded memory growth
- Reset on successful auth

### 4. Security Audit System (`src/security/audit.ts` + `audit-extra.*.ts`, ~2,900 lines)

**CLI: `openclaw security audit [--deep] [--fix]`**

Comprehensive automated audit covering:

| Category | Checks |
|----------|--------|
| **Gateway config** | Bind address vs auth, token length, Tailscale exposure mode, trusted proxy config, rate limiting, Control UI insecure auth, dangerous tools re-enabled over HTTP |
| **Browser control** | Auth on browser control routes, remote CDP over HTTP |
| **Filesystem** | State dir permissions, config file permissions, symlink detection, world/group readable/writable, credential file permissions, include file permissions |
| **Logging** | Redaction disabled (`logging.redactSensitive="off"`) |
| **Elevated exec** | Wildcard in allowlists, oversized allowlists |
| **Hooks** | Hardening checks for Gmail/webhook hooks |
| **Sandbox** | Docker configured but sandbox mode off (no-op) |
| **Tool policy** | Node deny command patterns, minimal profile overrides, extension plugin trust |
| **Secrets** | Inline secrets in config (vs env var references) |
| **Models** | Legacy/weak model warnings, small model risk |
| **Channels** | Per-channel DM/group policy, open groups + tools = danger |
| **Plugins** | Untrusted extensions, code safety scan |
| **Exposure matrix** | Cross-checks bind mode × auth × tailscale × tools |
| **Deep probe** | Live Gateway connectivity + auth test |

**Severity levels:** `critical`, `warn`, `info`
**Structured output:** `SecurityAuditReport` with findings array, summary counts, optional deep probe results

### 5. Auto-Fix (`src/security/fix.ts`, 458 lines)

**CLI: `openclaw security audit --fix`**

Automated remediation:
- `chmod 700` state directory, `chmod 600` config file
- `chmod 600` all credential JSON files, auth profiles, session stores
- Tighten `groupPolicy="open"` → `"allowlist"` for all channels
- Restore `logging.redactSensitive="tools"` if disabled
- Migrate WhatsApp group allowFrom from pairing store
- Windows ACL support via `icacls` commands
- Skips symlinks (security-safe)
- Reports all actions taken with success/skip/error status

### 6. Skill Scanner (`src/security/skill-scanner.ts`, 432 lines)

**Static analysis of installed skills/extensions for safety:**

| Rule | Severity | What it catches |
|------|----------|----------------|
| `dangerous-exec` | critical | `child_process` exec/spawn calls |
| `dynamic-code-execution` | critical | `eval()`, `new Function()` |
| `crypto-mining` | critical | Mining pool URLs, known miners |
| `suspicious-network` | warn | WebSocket to non-standard ports |
| `potential-exfiltration` | warn | File read + network send combo |
| `obfuscated-code` | warn | Hex-encoded strings, large base64 payloads |
| `env-harvesting` | critical | `process.env` + network send combo |

- Scans `.js`, `.ts`, `.mjs`, `.cjs`, `.mts`, `.cts`, `.jsx`, `.tsx`
- Skips `node_modules` and hidden directories
- Configurable max files (500) and max file size (1MB)
- Directory scanner with summary output

### 7. Tool Policy & Sandboxing

**Dangerous tool deny lists** (`src/security/dangerous-tools.ts`):
- **Gateway HTTP deny**: `sessions_spawn`, `sessions_send`, `gateway`, `whatsapp_login` — blocked over HTTP by default (RCE risk)
- **ACP (automation) deny**: `exec`, `spawn`, `shell`, `fs_write`, `fs_delete`, `fs_move`, `apply_patch`, `sessions_spawn`, `sessions_send`, `gateway` — always require explicit approval

**Tool profiles** (`src/agents/tool-policy.ts`):
- Named profiles: `minimal`, `coding`, `messaging`, `full`
- Tool groups: `group:memory`, `group:web`, `group:fs`, `group:runtime`, `group:sessions`, `group:ui`, `group:automation`, `group:messaging`, `group:nodes`
- Owner-only tools (e.g., `whatsapp_login`)
- Allow/deny list composition with alias normalization

**Docker sandboxing** (`src/agents/sandbox/`):
- Modes: `off`, `non-main` (only sandbox non-primary sessions), `all`
- Scope: `session` (one container each), `agent`, `shared`
- Workspace access: `none`, `ro`, `rw`
- Custom bind mounts, sandbox browser with auto-start
- Elevated exec explicitly bypasses sandbox (documented, audited)

### 8. Network Security

- **Default bind: loopback only** — Gateway binds to `127.0.0.1`/`::1`
- **Tailscale integration**: Serve (tailnet-only) or Funnel (public, audited as critical)
- **Trusted proxy validation**: explicit IP allowlist, rejects spoofed headers
- **Node command policy**: configurable deny patterns for `system.run` on paired nodes
- **Canvas/Control UI**: treated as sensitive, loopback-recommended

### 9. Secrets Management

- **Config secrets via env vars**: `${ENV_VAR}` syntax, audit warns on inline secrets
- **Credential storage**: per-channel JSON files in `~/.openclaw/credentials/`
- **`detect-secrets`** in CI/CD: automated secret scanning with baseline
- **Pre-commit hooks**: `.pre-commit-config.yaml` for secret detection

### 10. Cross-Platform Support

- Full Windows ACL support (`src/security/windows-acl.ts`, 228 lines) — `icacls` inspection and reset
- POSIX permission checks with proper `lstat` (follows symlinks safely)
- Platform-aware remediation commands in audit output

---

## Architecture Security Properties

| Property | Implementation |
|----------|---------------|
| Prompt injection defense | Content wrapping + Unicode sanitization + detection logging |
| Authentication | Multi-mode (token/password/Tailscale/trusted-proxy) with constant-time comparison |
| Rate limiting | Per-IP sliding window with lockout, scope separation |
| Authorization | Tool profiles, allow/deny lists, owner-only gates, sandbox isolation |
| Filesystem hardening | Automated audit + fix for permissions, symlink-aware |
| Supply chain | Skill scanner (static analysis), plugin trust audit, `detect-secrets` CI |
| Network exposure | Loopback default, Tailscale integration, proxy validation, HTTP tool deny list |
| Monitoring | Suspicious pattern detection, structured audit reports |
| Secrets | Env var references, constant-time comparison, credential file permissions |
| Sandboxing | Docker-based tool isolation with configurable scope/access |

---

## What OpenClaw Does That Hornet Doesn't (Gap Analysis)

| Capability | OpenClaw | Hornet |
|-----------|----------|--------|
| External content wrapping with boundary markers | ✅ Production (299 lines) | ❌ None — Slack messages go straight to LLM |
| Prompt injection detection (regex) | ✅ 12 patterns, logged | ❌ None |
| Unicode homoglyph sanitization | ✅ Fullwidth + CJK + math brackets | ❌ None |
| Constant-time secret comparison | ✅ `safeEqualSecret()` | ❌ Not verified |
| Gateway auth (multi-mode) | ✅ token/password/Tailscale/trusted-proxy | ❌ No auth on bridge API (localhost:7890) |
| Auth rate limiting | ✅ Per-IP sliding window + lockout | ❌ None |
| Automated security audit CLI | ✅ 30+ checks, `--deep`, `--fix` | ❌ None |
| Filesystem permission hardening | ✅ Audit + auto-fix (chmod/icacls) | ❌ `.env` is 644 |
| Skill/extension static analysis | ✅ 7 rules, directory scanner | ❌ None |
| Tool deny lists (HTTP surface) | ✅ Blocks session spawn/send over HTTP | ❌ N/A (no HTTP tool invoke) |
| Docker sandboxing | ✅ Configurable modes/scope/access | ❌ None |
| Tool profiles (allow/deny) | ✅ Named profiles + groups | ❌ None — agent has full tool access |
| Secrets-in-config detection | ✅ Audit warns on inline secrets | ❌ Tokens in `.env` (644) |
| Trusted proxy validation | ✅ IP allowlist + header validation | ❌ N/A |
| Windows security support | ✅ icacls ACL inspection | ❌ N/A (Linux only) |
| CI secret scanning | ✅ detect-secrets + baseline | ❌ None |

---

## Key Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| `src/security/external-content.ts` | 299 | Content wrapping, injection detection, Unicode sanitization |
| `src/security/audit.ts` | 687 | Main audit orchestrator |
| `src/security/audit-extra.sync.ts` | 873 | Synchronous audit checks (config-based) |
| `src/security/audit-extra.async.ts` | 793 | Async audit checks (filesystem, plugins, skills) |
| `src/security/audit-channel.ts` | 506 | Per-channel security policy checks |
| `src/security/fix.ts` | 458 | Auto-fix for audit findings |
| `src/security/skill-scanner.ts` | 432 | Static analysis of skills/extensions |
| `src/security/audit-fs.ts` | 194 | Filesystem permission inspection |
| `src/security/windows-acl.ts` | 228 | Windows ACL support |
| `src/security/dangerous-tools.ts` | 37 | Tool deny lists |
| `src/security/secret-equal.ts` | 16 | Constant-time secret comparison |
| `src/security/channel-metadata.ts` | 45 | Untrusted channel metadata wrapping |
| `src/security/scan-paths.ts` | 17 | Path containment checks |
| `src/security/audit-tool-policy.ts` | 31 | Sandbox tool policy helpers |
| `src/gateway/auth.ts` | ~350 | Multi-mode gateway authentication |
| `src/gateway/auth-rate-limit.ts` | ~230 | Sliding-window rate limiter |
| `src/agents/tool-policy.ts` | ~80+ | Tool profiles and allow/deny groups |
| `src/agents/sandbox/` | ~20 files | Docker sandboxing system |
| `docs/gateway/security/index.md` | ~120+ | User-facing security docs |
