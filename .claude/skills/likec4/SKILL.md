---
name: likec4
description: >
  Routes to LikeC4 sub-skills. Use for creating/updating a C4 diagram or validating a
  .c4 model. Not for non-C4 diagrams (Mermaid, PlantUML).
  Triggers: 'generate c4 model', 'update c4 diagram', 'check c4 model', '/likec4'.
argument-hint: "[model | check] [<path>] [--docs-only | --code-only]"
allowed-tools: AskUserQuestion, ToolSearch, Read, Edit, Write, Glob, Bash
---

# LikeC4 — Dispatcher

This skill routes to one of two sub-flows:

- **Model** — generate or update a LikeC4 `.c4` architecture model from project documents and/or source code
- **Check** — review `.c4` files for structural validity and convention rule compliance

## On invocation

First, check whether the invocation args already indicate intent:

- **Clear check intent** — args contain words like "check", "validate", "review", "lint", or a `.c4` file path: go directly to the Check flow. Do not ask.
- **Clear model intent** — args contain words like "generate", "create", "update", "model", or a project directory path: go directly to the Model flow. Do not ask.
- **Ambiguous or no args**: Fetch `AskUserQuestion` if not yet available: `ToolSearch select:AskUserQuestion`. Then ask:

> Would you like to **generate** or update a `.c4` architecture model, or **check** an existing model for quality issues?

Present two options:
1. Model — generate or update a `.c4` diagram from project sources
2. Check — validate an existing `.c4` model against structural and convention rules

## After intent is determined

**If Model:** Read `.claude/skills/likec4/likec4-model/SKILL.md` and follow the instructions there exactly, starting from the top. If the file is not found, emit: `Sub-skill not located at .claude/skills/likec4/likec4-model/SKILL.md. Check .claude/skills/likec4/ directory.`

**If Check:** Read `.claude/skills/likec4/likec4-check/SKILL.md` and follow the instructions there exactly, starting from the top. If the file is not found, emit: `Sub-skill not located at .claude/skills/likec4/likec4-check/SKILL.md. Check .claude/skills/likec4/ directory.`

Do not summarise or paraphrase the sub-flow — execute it directly.

**Dispatcher is idempotent:** re-running with the same args produces identical routing decision.

Before delegating, emit a one-line routing confirmation:

```text
→ Routing to: [Model | Check] sub-flow
   Target: <path or "new model from docs/architecture.md">
```

## Standards and co-update partners

LikeC4 DSL rules (element types, relationship syntax, view declarations) are summarised
for sub-flows in `.claude/skills/likec4/dsl-reference.md` and authoritatively defined by
the LikeC4 specification at <https://likec4.dev/dsl/>. If the LikeC4 DSL version changes,
update `dsl-reference.md`, `likec4-model/SKILL.md`, and `likec4-check/SKILL.md` together.

| Standard | Shared with |
| --- | --- |
| LikeC4 element type names and syntax | `likec4-model`, `likec4-check` |
| Routing trigger keywords (model/check intent) | This dispatcher only — sub-flows do not re-route |
