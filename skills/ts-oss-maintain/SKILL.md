---
name: ts-oss-maintain
description: Standardize and maintain a TypeScript OSS repo with oxlint/oxfmt scripts, Vitest, pre-commit hooks, GitHub Actions, private-first GitHub repo creation, AGENTS.md/CLAUDE.md guidance, changelog discipline, and license setup. Use when bootstrapping or normalizing a TS open-source repo for maintainability.
---

# TS OSS Maintain

Use this skill when the user wants to bootstrap, normalize, or harden a TypeScript open-source repository around a repeatable maintenance setup.

This is an opinionated maintenance skill, not a framework migration skill. Prefer the repo's existing runtime and package manager when reasonable, but standardize the maintenance surface.

## Core defaults

- Prefer **`oxfmt`** for formatting.
- Prefer **`oxlint`** for linting.
- Prefer **`vitest`** for tests.
- Prefer **private GitHub repo creation first**. The user must manually make it public later.
- Prefer **`AGENTS.md`** as the single local agent-guidance file.
- Create **`CLAUDE.md` as a symlink to `AGENTS.md`**.
- Ask about the license before adding it. Default recommendation: **MIT**.
- Keep setup simple and boring unless the repo clearly needs more.

## First: gather or infer these inputs

Ask only for missing information.

1. **Repo name**
   - Default: current directory name.
2. **GitHub owner**
   - Default: current authenticated `gh` user via `gh api user --jq .login`.
3. **Runtime / package manager**
   - If the repo already uses Bun, keep Bun unless the user wants migration.
   - Otherwise default to Node LTS + `pnpm`.
4. **Repo type**
   - library, CLI, app, or mixed package.
5. **License**
   - Ask explicitly. Recommend MIT by default.
6. **Publishing intent**
   - npm package, internal OSS utility, or not published.

## Scan before editing

Before making changes:

1. Read `package.json`, lockfiles, `tsconfig.json`, existing test config, hooks, and workflows.
2. Check whether lint/format/test/typecheck scripts already exist.
3. Check whether a GitHub remote already exists.
4. Check whether `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `LICENSE`, and `.github/workflows/*` already exist.
5. Reuse existing conventions if they are already good enough.

Do not churn tools just to match the default if the repo already has a coherent setup the user prefers.

## Required outcomes

### 1) Ensure the GitHub remote exists

If there is no `origin` remote or no GitHub repo yet:

1. Determine owner:
   - use the user-specified owner, or
   - default to `gh api user --jq .login`.
2. Create the remote repo as **private**:

```bash
gh repo create <owner>/<repo> --private --source=. --remote=origin
```

3. Never create it as public by default.
4. Tell the user clearly:
   - the repo was created private first
   - they must make it public manually when ready

If the remote already exists, leave it alone unless the user asked to rename or recreate it.

### 2) Ensure maintenance scripts exist

Ensure `package.json` has a coherent maintenance script surface.

Minimum expected scripts:

```json
{
  "scripts": {
    "format": "oxfmt --write .",
    "format:check": "oxfmt --check .",
    "lint": "oxlint . --deny-warnings",
    "lint:fix": "oxlint . --fix",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  }
}
```

Recommended additions when appropriate:

```json
{
  "scripts": {
    "test:watch": "vitest",
    "coverage": "vitest run --coverage"
  }
}
```

Rules:

- Prefer `oxfmt`/`oxlint` over Prettier/ESLint for new setups.
- If another formatter/linter already exists and the user did not ask to migrate, avoid unnecessary migration churn.
- Ensure the scripts actually match the package manager/runtime in use.
- If TypeScript is present, ensure `typecheck` exists even if the user did not mention it.

### 3) Ensure the needed dependencies exist

For a new default TS setup, ensure the repo has the needed packages for its chosen runtime/package manager.

Typical baseline:

- `typescript`
- `vitest`
- `oxlint`
- `oxfmt`
- optionally `@vitest/coverage-v8`

If the repo is missing a TS config, add or normalize one conservatively.

### 4) Put lint/format on a pre-commit hook

Ensure a pre-commit hook exists.

Preferred order:

1. If the repo already uses **Husky**, keep Husky.
2. Otherwise prefer **simple-git-hooks** for lighter setup.

Acceptable hook behavior:

- `format:check` + `lint`
- or `lint-staged` that runs formatter/linter on staged files

Good defaults:

#### simple-git-hooks + lint-staged

```json
{
  "scripts": {
    "prepare": "simple-git-hooks"
  },
  "simple-git-hooks": {
    "pre-commit": "npx lint-staged"
  },
  "lint-staged": {
    "*.{ts,tsx,js,jsx,mjs,cjs,json,md,yml,yaml}": [
      "oxfmt --write",
      "oxlint --fix"
    ]
  }
}
```

#### husky fallback

Create `.husky/pre-commit` that runs the repo's chosen validation commands.

At minimum, pre-commit should stop obviously bad formatting/lint drift from landing.

### 5) Use Vitest for tests

If the repo does not already use Vitest, set up Vitest unless the user asked for something else.

Expectations:

- `test` script runs Vitest non-watch mode.
- Add a minimal `vitest.config.*` only if needed.
- Preserve existing test layout when practical.
- Add at least one smoke test if the repo has no tests and the user asked for initial setup.

### 6) Add GitHub Actions for the maintenance surface

Ensure GitHub Actions exists for the core checks.

Minimum CI coverage:

- format check
- lint
- typecheck
- test
- build, if the repo has a real build step
- pack/install smoke check, if this is a published CLI/library and packaging matters

Prefer a simple default workflow first. Split later only if needed.

Recommended triggers:

- `pull_request`
- `push` to `main`

Good default workflow shape:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: <install command>
      - run: <format check>
      - run: <lint>
      - run: <typecheck>
      - run: <test>
      - run: <build if applicable>
```

Runtime-specific guidance:

- For Bun repos, use `oven-sh/setup-bun@v2` and Bun install/run commands.
- For Node repos, use `actions/setup-node@v4` and the repo's package manager.

Prefer:

- `concurrency` to cancel stale runs
- `paths-ignore` for pure docs/license changes when appropriate
- additional packaging verification jobs for publishable CLIs/libraries

Do not add heavyweight release automation unless the user wants it.

## Agent guidance files

### 7) Ensure `AGENTS.md` exists

Create `AGENTS.md` as the canonical local agent-guidance file.

It should usually include:

1. **What the project is**
2. **Important file entry points**
3. **Architecture / mental model**
4. **Working rules**
5. **Validation commands**
6. **Release / changelog rules**
7. **Commit conventions**

Keep it concise and high-signal.

### 8) Ensure `CLAUDE.md` is a symlink to `AGENTS.md`

Create a symlink, not a duplicate file:

```bash
ln -s AGENTS.md CLAUDE.md
```

Rules:

- If `CLAUDE.md` already exists and is a real file with useful content, merge that content into `AGENTS.md` first.
- Avoid two separately maintained agent-guidance documents.
- Prefer one source of truth.

## Changelog guidance

The local `AGENTS.md` should explicitly teach agents how to maintain the changelog.

Use guidance modeled on the Hunk release-process pattern:

- Maintain top-level `CHANGELOG.md` as the source of truth for user-visible changes.
- Keep upcoming work under `## [Unreleased]` with these subsections:
  - `### Added`
  - `### Changed`
  - `### Fixed`
- Append to existing subsections instead of creating duplicates.
- When cutting a release, move relevant unreleased entries into a new immutable version section and start a fresh `## [Unreleased]` section.
- Use the released changelog section as the starting point for the GitHub release body.
- Prefer `gh release create/edit --notes-file` for multi-line release notes.
- Do not trust autogenerated GitHub release notes blindly; verify and edit them.
- Prefer concise user-visible entries over internal refactor details unless behavior changed.

If `CHANGELOG.md` does not exist, create it.

Recommended starter structure:

```md
# Changelog

All notable user-visible changes to this project are documented in this file.

## [Unreleased]

### Added

### Changed

### Fixed
```

## License

Ask which license the user wants.

- Default recommendation: **MIT**.
- If the user says "default" or gives no preference after being asked, use MIT.

Ensure:

- a top-level `LICENSE` file exists
- `package.json` has the correct `license` field
- README/package metadata do not contradict the chosen license

## Strongly recommended extras

These were common patterns in recent repos and are usually worth standardizing:

### Add package metadata hygiene

If this is an npm package, ensure `package.json` includes sane metadata where applicable:

- `name`
- `description`
- `repository`
- `homepage`
- `bugs`
- `keywords`
- `license`
- `files`
- `engines`
- `packageManager`

Prefer a `files` allowlist over publishing the whole repo accidentally.

### Add `typecheck` even when the user forgot to ask for it

This is a near-universal maintenance step for TS OSS repos.

### Add pack/install verification for publishable packages

For libraries and CLIs, consider CI checks for:

- `npm pack` success
- install from the packed tarball
- basic smoke execution of the installed artifact

This catches broken publish surfaces early.

### Put release/changelog rules in `AGENTS.md`

Do this from day one instead of reconstructing release history later.

### Prefer Conventional Commits guidance in `AGENTS.md`

Suggested guidance:

```md
Commit titles should follow Conventional Commits:
`<type>[scope]: <description>`
```

### Keep one guidance file, not two

If both `AGENTS.md` and `CLAUDE.md` exist, they should resolve to one source of truth via symlink.

## Suggested execution order

1. Inspect repo state.
2. Ask only the missing questions.
3. Create private GitHub remote first if missing.
4. Add or normalize scripts and dependencies.
5. Add pre-commit hook.
6. Add or normalize Vitest.
7. Add GitHub Actions.
8. Add `AGENTS.md` and `CLAUDE.md` symlink.
9. Add `CHANGELOG.md` if missing.
10. Add the chosen license.
11. Run verification.
12. Summarize exactly what changed and any follow-up the user must do manually.

## Verification checklist

Before finishing, run the relevant checks if the repo supports them:

- install dependencies
- `format:check`
- `lint`
- `typecheck`
- `test`
- build, if present

If CI files were added, sanity-check them against the actual package manager/runtime commands.

## Output expectations

When you finish, report:

- files added/changed
- scripts added/changed
- hook setup chosen
- CI workflows added/changed
- whether the GitHub repo was created
- that the repo was created **private first**
- whether the user still needs to make the repo public manually
- chosen license
- any optional follow-ups you recommend
