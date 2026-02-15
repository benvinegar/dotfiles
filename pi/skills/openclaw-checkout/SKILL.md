# OpenClaw Checkout — Modem Billing & Security Reference

> **Note:** "OpenClaw" is the internal codename for Modem's checkout and billing system.
> All code lives in `~/hornet/modem/`. This skill documents how checkout works and how it's secured.

## Architecture Overview

The checkout system is built on three pillars:

1. **Better Auth** (`better-auth`) — authentication framework with plugins for org management, API keys, magic links, MCP/OIDC, and Stripe
2. **Stripe** — payment processing, subscription management, pricing tables, customer portal
3. **OrgScopedDb** — data isolation layer ensuring all queries are scoped to the correct organization

### Key Packages & Files

| Component | Location |
|-----------|----------|
| Auth core (Better Auth instance, Stripe plugin, hooks) | `packages/auth/src/auth.ts` |
| Auth config types & state | `packages/auth/src/config.ts` |
| Stripe plan definitions | `packages/auth/src/stripe-plans.ts` |
| Subscription authorization logic | `packages/auth/src/auth.ts` → `authorizeSubscriptionReference()` |
| Subscription authorization tests | `packages/auth/src/subscription-authorization.test.ts` |
| Waitlist bypass logic | `packages/auth/src/waitlist.ts` |
| OAuth proxy plugin (preview env support) | `packages/auth/src/plugins/oauth-proxy.ts` |
| Trusted origins validation | `packages/auth/src/plugins/utils/is-trusted-target-base-url.ts` |
| Dashboard auth initialization | `apps/dashboard/src/lib/auth-init.ts` |
| Dashboard auth client (browser) | `apps/dashboard/src/lib/auth-client.ts` |
| Dashboard auth utilities & HOFs | `apps/dashboard/src/lib/auth-utils.ts` |
| Dashboard session utils | `apps/dashboard/src/lib/auth.ts` |
| Billing page (server component) | `apps/dashboard/src/app/[orgSlug]/(dashboard)/organization/billing/page.tsx` |
| Billing page (client component) | `apps/dashboard/src/app/[orgSlug]/(dashboard)/organization/billing/page.client.tsx` |
| Billing server actions | `apps/dashboard/src/app/[orgSlug]/(dashboard)/organization/billing/actions.ts` |
| Content Security Policy | `apps/dashboard/src/lib/csp.ts` |
| Org-scoped DB wrapper | `packages/database/src/lib/org-scoped-db.ts` |
| Auth DB schema (orgs, users, sessions, subs) | `packages/database/src/schema/auth.ts` |
| Stripe billing setup docs | `docs/plans/stripe-billing-setup.md` |

---

## Stripe Integration

### Plans

Three tiers, defined in `packages/auth/src/stripe-plans.ts`:

| Plan | Price | Events/mo | Users | Retention | Agent Tokens |
|------|-------|-----------|-------|-----------|-------------|
| Free | $0/mo | 5,000 | 1 | 30 days | 5M |
| 14.4 kbit/s | $144/mo | 100,000 | Unlimited | 90 days | 50M |
| 28.8 kbit/s | $288/mo | 1,000,000 | Unlimited | 180 days | 100M |

Price IDs are environment-specific:
- `NODE_ENV=development` or `VERCEL_ENV=preview` → **sandbox** price IDs
- Production → **production** price IDs

### Checkout Flow

1. User navigates to `/{orgSlug}/organization/billing`
2. Page is protected by `withOrgAuthzRSC` — requires auth + org membership
3. **Upgrade button** is gated: only users with `role === 'owner'` see it
4. Clicking "Upgrade Now" opens a full-screen dialog with a **Stripe Pricing Table** (`<stripe-pricing-table>`)
5. The pricing table requires a **Customer Session** (created server-side via `createPricingTableSession` action)
6. `createPricingTableSession` is protected by `withOrgAdminAuthz` + explicit `userRole === 'owner'` check
7. It calls `ensureStripeCustomerExists()` to create a Stripe customer if one doesn't exist, then creates a `customerSessions.create()` with `pricing_table` component enabled
8. The `client-reference-id` on the pricing table is set to the `organizationId`, linking checkout to the org

### Subscription Management

- **Billing Portal**: accessed via `authClient.subscription.billingPortal()` — redirects to Stripe-hosted portal
- Portal features: invoice history, payment method updates, subscription cancellation, plan switching
- Portal must be configured in Stripe Dashboard (Settings → Billing → Customer portal)

### Webhook Events

Handled by Better Auth's Stripe plugin. Required events:
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Webhook verification uses `STRIPE_WEBHOOK_SECRET` (signature validation built into the `@better-auth/stripe` plugin).

### Environment Variables

```
STRIPE_SECRET_KEY          # Stripe API secret key
STRIPE_WEBHOOK_SECRET      # Webhook signing secret
NEXT_PUBLIC_STRIPE_PRICING_TABLE_ID   # Pricing table ID (client-side)
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY    # Publishable key (client-side)
```

---

## Security Model

### 1. Authentication (Better Auth)

- **Session-based**: 90-day sessions stored in DB (`sessions` table), token in cookie
- **Social OAuth**: GitHub, Google, Slack, Discord, Linear — all with account linking (`trustedProviders`)
- **Magic Links**: 15-minute expiry for logins, 90-day expiry for invitations
- **API Keys**: `modem_` prefix, 90-day default expiry, 1-year max
- **MCP/OIDC**: Full OAuth2 server with consent flow, dynamic client registration
- **Admin roles**: `super` (full admin + impersonate), `admin` (no elevated perms)

### 2. Authorization — Subscription Actions

`authorizeSubscriptionReference()` in `packages/auth/src/auth.ts`:

| Role | Read (billing-portal, list-subscription) | Modify (upgrade, cancel, restore) |
|------|------------------------------------------|-----------------------------------|
| Super Admin | ✅ (bypasses all checks) | ✅ |
| Owner | ✅ | ✅ |
| Admin | ✅ | ❌ |
| Member | ✅ | ❌ |
| Non-member | ❌ | ❌ |

### 3. Authorization — Server Actions & Components

Higher-order functions in `apps/dashboard/src/lib/auth-utils.ts`:

| HOF | Checks | Use Case |
|-----|--------|----------|
| `withOrgAuthz` | Auth + org membership | General org-scoped actions |
| `withOrgAdminAuthz` | Auth + admin/owner role | Admin-only actions (billing, settings) |
| `withOrgAuthzRSC` | Auth + org access (RSC) | Protected page components |
| `withOrgAuthzRoute` | Auth + org access (Route) | API route handlers |
| `withSuperAdminAuthz` | Auth + super admin role | Super admin actions |
| `withSuperAdminAuthzRSC` | Auth + super admin (RSC) | Super admin pages |

All of these:
- Extract and validate session from cookies
- Set Sentry user context for error tracking
- Verify org membership (or super admin bypass)
- Create `OrgScopedDb` for data isolation

### 4. Data Isolation — OrgScopedDb

`packages/database/src/lib/org-scoped-db.ts` provides **two-layer protection**:

**Layer 1 — Developer validation**: Every query on an org-scoped table MUST include an `organizationId` filter. If missing, `MissingOrganizationScopeError` is thrown at runtime. This is enforced by inspecting Drizzle's internal `queryChunks` to verify the presence of `organization_id` column references.

**Layer 2 — Defense in depth**: Even when the developer includes the org filter, the wrapper automatically appends `AND organizationId = <scoped_org_id>` to every query. This prevents a developer from accidentally filtering on a different org's ID.

Coverage:
- `select().from(table).where(...)` — validated + injected
- `insert(table).values(...)` — validates each row's `organizationId` matches
- `update(table).set(...).where(...)` — validated + injected
- `delete(table).where(...)` — validated + injected
- `query.tableTbl.findFirst/findMany({ where: ... })` — validated + injected
- `transaction(callback)` — creates a new OrgScopedDb wrapper for the transaction

**Runtime assertion**: On module load, `assertDrizzleQueryChunksApiStable()` runs to verify that Drizzle's internal `queryChunks` structure is still compatible with the inspection logic. If Drizzle changes internals (e.g., after an upgrade), this will fail-fast at boot time.

### 5. OAuth Proxy (Preview Environment Security)

`packages/auth/src/plugins/oauth-proxy.ts` enables OAuth to work across preview/staging environments without shared databases:

1. **Originating server** (preview env): intercepts OAuth redirect, encrypts state + baseURL using the provider's client secret, prefixes with `_proxy_`
2. **Proxy server** (production): detects `_proxy_` prefix, decrypts state using same client secret, validates target URL against trusted origins, redirects to originating server

**Open redirect prevention**: The target baseURL is validated against `trustedOrigins` using `isTrustedTargetBaseURL()`:
- Exact origin matching (`https://app.modem.dev`)
- Wildcard host patterns (`*-modem-labs.vercel.app`)
- Protocol validation (only `http:` and `https:`)
- URLPattern-based matching for wildcard hosts

### 6. Trusted Origins

Computed in `computeTrustedOrigins()`:
- Production URL: `https://app.modem.dev`
- Vercel preview pattern: `*-modem-labs.vercel.app`
- Configured `baseUrl`
- Chrome extension origin (if configured)
- Localhost in development
- Vercel deployment URLs in preview

### 7. Content Security Policy

`apps/dashboard/src/lib/csp.ts` — comprehensive CSP:
- `default-src 'self'`
- `frame-ancestors 'none'` — no iframe embedding
- `object-src 'none'` — no plugins
- `form-action 'self'`
- `upgrade-insecure-requests`
- Stripe (`js.stripe.com`) allowed in `script-src` and `frame-src`
- CSP violation reporting to Sentry
- Dev-only additions for localhost media proxy and Cursor debug

### 8. Waitlist / Gating

`packages/auth/src/waitlist.ts` — fail-closed design:
- Non-production environments: always bypass
- If waitlist feature flag is disabled: bypass
- Existing org members: bypass
- Email/domain allowlist: bypass
- Auto-join domain match: bypass
- **Default on error: fail closed** (user stays waitlisted)

### 9. Organization Slug Validation

- Pattern: `/^[a-zA-Z0-9-]{1,100}$/` — alphanumeric + hyphens, max 100 chars
- Reserved slugs checked via `isReservedSlug()`
- Numeric IDs prioritized over slug matching to prevent ambiguity
- Validated via `isValidSlug()` before org creation

### 10. Stripe Client Configuration

```ts
new Stripe(secretKey, {
    apiVersion: '2026-01-28.clover',  // Pinned version
    maxNetworkRetries: 3,
    timeout: 30_000,  // 30 second timeout
});
```

- API version is pinned to prevent breaking changes
- Lazy-initialized singleton pattern in billing actions
- Stripe customer created automatically on org creation (non-critical — failures logged but don't block)

---

## Key Security Decisions

1. **Billing is org-level, not user-level** — `createCustomerOnSignUp: false` in Stripe plugin config
2. **Only owners can modify subscriptions** — admins and members get read-only access
3. **Customer sessions** (not checkout sessions) used for pricing table — scoped to existing customer, auto-links subscription to org
4. **OrgScopedDb prevents cross-tenant data access** at the application layer — every query enforced with two-layer protection
5. **OAuth proxy uses provider client secrets** as encryption keys — no additional shared secrets needed
6. **Waitlist fails closed** — errors default to keeping user waitlisted
7. **Super admin bypasses all membership checks** but is tracked via Sentry tags
8. **Session duration**: 90 days (sessions + invitations + API keys all aligned)

---

## When Modifying Checkout

- Plan changes: update both `stripe-plans.ts` AND Stripe Dashboard (products + prices)
- New webhook events: add to `stripe()` plugin config in `auth.ts`
- New billing actions: wrap with `withOrgAdminAuthz` + explicit role check
- New org-scoped tables: add `organizationId` column → OrgScopedDb auto-detects it
- Preview environment OAuth: ensure new providers have `redirectURI` set to production URL
- CSP changes: update `csp.ts` (used by both next.config and middleware)
