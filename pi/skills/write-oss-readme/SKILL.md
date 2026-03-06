---
name: write-oss-readme
description: Write high-quality open-source README files with clear positioning, fast onboarding, and concise structure inspired by successful OSS repos.
---

# Write OSS README

Use this skill when a user asks to create or rewrite a project README for public/open-source consumption.

## Style Baseline (learned from successful OSS repos)

Studied references:
- https://github.com/openclaw/openclaw (`README.md`, `VISION.md`, `CONTRIBUTING.md`, `SECURITY.md`, `docs/tools/plugin.md`)
- https://github.com/anomalyco/opencode (`README.md`, `CONTRIBUTING.md`, `AGENTS.md`)
- https://github.com/ollama/ollama (`README.md`, `docs/development.md`)

### Common patterns to emulate

1. **Immediate value proposition**
   - One sentence near the top saying exactly what the project is and who it is for.
   - Avoid abstract hype; be concrete.

2. **Fast path first**
   - Installation and first successful command appear early.
   - A reader should get to “it works” in under 2 minutes.

3. **Structured scannability**
   - Short sections, clear headings, bullets over long paragraphs.
   - Keep the top half dense with useful info (install, quickstart, docs links).

4. **Practical examples over explanation**
   - Include commands users can copy-paste.
   - Show one canonical example before edge cases.

5. **Contributor trust signals**
   - Link docs, contributing guide, security policy, and community/support channels.
   - Set expectations clearly (PR scope, testing, behavior).

6. **Concise, direct tone**
   - Write like maintainer-to-engineer.
   - Prefer “do X” over narrative paragraphs.

## README Quality Bar

A strong README should answer these quickly:
- What is this?
- Why use it?
- How do I install it?
- What command do I run first?
- Where are docs/API references?
- How do I contribute/report security issues?

If any are missing, add them.

## Recommended Section Order

Use this default layout unless the repo context suggests otherwise:

1. **Project name + one-liner**
2. **Badges (optional, minimal)**
3. **What it does (2–5 bullets)**
4. **Install**
5. **Quick start**
6. **Core usage examples**
7. **Configuration / architecture (if needed)**
8. **Documentation links**
9. **Contributing**
10. **Security**
11. **License**
12. **Community/support**

## Concision Rules

- Keep intro paragraph under ~70 words.
- Avoid repeating claims across sections.
- Prefer one section with links over many “stub” sections.
- Cut adjectives unless they add concrete meaning.
- Avoid AI-sounding filler (“robust”, “seamless”, “revolutionary”).

## Writing Workflow

1. **Read project reality first**
   - Inspect package metadata, CLI commands, docs, and tests.
   - Do not promise unsupported features.

2. **Draft minimal top half**
   - Name, one-liner, install, quickstart.
   - Ensure commands are correct and runnable.

3. **Add depth only where needed**
   - Add architecture/config only if users need it to succeed.

4. **Add trust and governance links**
   - Contributing, security policy, issue tracker/discussion.

5. **Final pass for scanability**
   - Shorten paragraphs, convert to bullets, remove duplicates.

## Output Format Expectations

When asked to write a README:
- Provide the full `README.md` content ready to commit.
- Keep formatting clean Markdown (no HTML unless necessary for logos/badges).
- If assumptions were required, include a short “Assumptions” note after the README draft.

## Reusable README Skeleton

```md
# <Project>

<One-line value proposition for a specific audience.>

<!-- Optional: minimal badges -->

## Why <Project>

- <Concrete capability 1>
- <Concrete capability 2>
- <Concrete capability 3>

## Install

```bash
<install command>
```

## Quick start

```bash
<first command>
<second command>
```

## Usage

```bash
<most common task>
```

## Docs

- User guide: <link>
- API/reference: <link>
- Examples: <link>

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

<License name>
```

## Anti-patterns to Avoid

- Long “vision” content before install/quickstart.
- Huge feature dumps without hierarchy.
- Multiple competing install methods with no recommendation.
- Unverified commands.
- Placeholder sections (“Coming soon”) in top-level README.
