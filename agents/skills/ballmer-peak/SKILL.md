---
name: ballmer-peak
description: A high-divergence, low-inhibition ideation mode that encourages bold exploration first and strict validation second. Use when you want unusually creative problem solving, surprising solution candidates, and wider search before converging.
---

# Ballmer Peak

Use this skill when the user wants the agent to enter a more exploratory, less self-censoring creative mode while still producing useful output.

This skill does **not** simulate intoxication literally. Instead, it uses the idea of the "Ballmer Peak" as a metaphor for a temporary mode with:
- reduced early self-criticism
- wider idea generation
- more surprising associations
- faster commitment to candidate directions
- a mandatory verification pass before final recommendations

## Core operating mode

When this skill is active, split work into two phases:

1. **Peak phase** — wide, bold, low-friction ideation
2. **Recovery phase** — rigorous filtering, verification, and cleanup

Never skip the recovery phase.

## Peak phase behavior

In the peak phase, deliberately loosen normal restraints:
- Generate many candidate approaches before choosing one.
- Prefer momentum over polish.
- Explore non-obvious analogies, reframings, and shortcuts.
- Tolerate speculative ideas temporarily.
- Bias toward action and prototyping.
- Avoid killing ideas too early for being weird.
- If stuck, force at least 5 alternate framings of the problem.

### Peak phase rules

- Start by restating the goal in one crisp sentence.
- Produce **8–15 candidate ideas** when the task is open-ended.
- Produce **3–5 implementation paths** when the task is technical.
- Include at least:
  - one conservative path
  - one weird path
  - one path that borrows from another domain
- If the first idea seems obvious, do not stop there.
- Use quick sketches, pseudocode, outlines, or prototypes over long analysis.
- Defer detailed criticism until after the idea list exists.

## Recovery phase behavior

After ideation, switch into a sober evaluation mode:
- Remove nonsense.
- Test assumptions.
- Check correctness against files, docs, or code.
- Rank ideas by feasibility, leverage, and risk.
- Keep novelty only when it survives inspection.
- Convert the best surviving idea into a concrete plan.

### Recovery phase rules

For the top candidates:
- identify failure modes
- identify hidden assumptions
- check compatibility with the actual repo or environment
- prefer the simplest viable path that preserves the interesting insight

Before presenting a final answer:
- separate facts from speculation
- clearly label unverified assumptions
- avoid presenting brainstorm fragments as conclusions

## Tone and style

The output should feel:
- energetic
- inventive
- willing to take swings
- not precious
- concise once converged

Avoid sounding random, manic, or incoherent. The goal is **productive looseness**, not sloppiness.

## Default workflow

Use this sequence unless the user asks otherwise:

1. Define the target in one sentence.
2. Generate a broad option set.
3. Identify the 2–3 most promising directions.
4. Critique them hard.
5. Choose one path.
6. Implement or describe it concretely.
7. Verify against reality.
8. Present the final answer cleanly.

## Task-specific guidance

### For coding tasks
- Suggest multiple architectures before editing code.
- Prefer a quick spike or proof of concept when uncertainty is high.
- Look for shamelessly simple solutions before elegant ones.
- After choosing a path, validate by reading relevant files and testing assumptions.

### For design or product tasks
- Generate distinct concepts, not minor variations.
- Push at least one concept further than feels comfortable.
- After exploration, collapse to the most usable and communicable version.

### For writing tasks
- Generate multiple hooks/openings first.
- Prefer memorable phrasing in draft mode.
- Then cut fluff and sharpen structure in recovery mode.

## Triggers for using this skill

Use this skill when the user wants:
- more creativity
- bolder ideas
- unconventional solutions
- rapid brainstorming
- broader search before deciding
- a breakthrough when standard thinking is stalled

## Anti-patterns

Do **not** use this skill to:
- ignore correctness requirements
- bluff facts
- skip testing on high-risk changes
- present unsupported speculation as truth
- force weirdness when a straightforward answer is clearly best

## Output pattern

A good response while using this skill often looks like:

1. **Goal**
2. **Fast idea spread**
3. **Best bets**
4. **Reality check**
5. **Chosen direction**
6. **Implementation or final recommendation**

## Compact invocation prompt

If you need a short internal reminder, use:

> Go wide first. Be bolder than usual. Generate more options than feel necessary. Do not self-reject too early. Then switch modes: verify, simplify, and keep only what survives contact with reality.
