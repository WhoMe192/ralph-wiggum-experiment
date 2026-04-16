---
name: gherkin
description: >
  Generate BDD scenarios for a UI feature, or review an existing docs/ux/*.md file.
  Triggers: 'write gherkin scenarios', 'generate BDD tests', 'review gherkin file',
  'audit scenarios'. Do not use for non-UI acceptance criteria or prose review tasks.
disable-model-invocation: true
allowed-tools:
  - AskUserQuestion
  - ToolSearch
  - Read
  - Write
---

# Gherkin — Dispatcher

This skill routes to one of two sub-flows:

## Inputs

**Required:** none — intent is inferred from invocation args or user prompt.
**Optional:** file path (e.g. `docs/ux/board-config.md`) — if provided, routes directly to Review flow; feature description (free text) — routes to Generate flow.
**Missing input:** if no args and intent is unclear, ask: "Would you like to generate new scenarios or review an existing file?"

## Output template

**Normal routing output:**
```
**Mode detected:** Generate | Review
**Routing to:** `gherkin-scenarios` | `gherkin-review`

---

<sub-skill output appears here>
```

**Ambiguous input output:**
```
**Input ambiguous.** Could not determine mode from: "<exact user input>"

**Options:**
- (a) `generate` — invoke as `/gherkin generate <feature description>`
- (b) `review` — invoke as `/gherkin review <file-path>`

Which mode did you intend?
```

**Unknown mode output:**
```
**Mode not recognised:** "<exact user input>"

**Valid modes:** generate, review

**Example:** `/gherkin generate login with Google`
```

- **Generate** — create Gherkin scenarios for a new UI feature via a structured Q&A conversation
- **Review** — audit an existing `docs/ux/*.md` file against BDD quality standards and suggest improvements

## On invocation

First, check whether the invocation args already indicate intent:

- **Clear review intent** — args contain words like "review", "audit", "check", or a file path (e.g. `@docs/ux/...` or `docs/ux/...`): go directly to the Review flow. Do not ask.
- **Clear generate intent** — args contain words like "generate", "create", "write scenarios", or a feature description: go directly to the Generate flow. Do not ask.
- **Ambiguous or no args**: Fetch `AskUserQuestion` if not yet available: `ToolSearch select:AskUserQuestion`. Then ask:

> Would you like to **generate** new scenarios for a feature, or **review** an existing scenarios file?

Present two options:
1. Generate — I have a feature to write scenarios for
2. Review — I have an existing file to audit

## After intent is determined

**If Generate:** Read `.claude/skills/gherkin/gherkin-scenarios/SKILL.md` and follow the instructions there exactly, starting from the top.

**Success criteria for Generate:** self-check passes and file written to `docs/ux/`. Failure: violations found → fix and retry up to 2 times → stop with error if still failing.

**If Review:** Read `.claude/skills/gherkin/gherkin-review/SKILL.md` and follow the instructions there exactly, starting from the top.

**Success criteria for Review:** at least one finding reported with evidence excerpt; all scenarios checked against `bdd-standards.md`; output includes a named verdict (`Pass` / `Needs revision` / `Rejected`). Failure: sub-flow emits an error after ≥2 retries → stop and report the error to the user.

Do not summarise or paraphrase the sub-flow — execute it directly.

## Edge cases

- **File not found (Review mode):** if the cited `docs/ux/*.md` path does not exist, emit `ERROR: file not found at <path> — check the path and try again` and stop.
- **Ambiguous intent:** if intent cannot be determined from args, ask via AskUserQuestion (see "On invocation" above). Do not guess.
- **Partial artefact (Review mode):** if the file has fewer than 3 Gherkin scenarios, proceed with what is available and note "Only <N> scenario(s) found — review may be incomplete."
- **Empty args (Generate mode):** if generate intent is detected but no feature description is given, ask "What feature would you like to write scenarios for?"
- **All errors:** every error path emits a named message — no silent failure.

## Idempotency

- **Generate flow:** before writing, checks whether `docs/ux/<feature>.md` already exists. If it does, asks "File already exists — overwrite or append?" before writing.
- **Review flow:** read-only. Re-running on unchanged input produces identical output.

## Calibration

Bad→good scenario pairs covering the most common rule violations live in
`.claude/skills/gherkin/examples.md`. Use these when calibrating what a rule violation
looks like vs. its corrected form.

- **Strong:** §Good sections in `.claude/skills/gherkin/examples.md` — passing scenarios
  that satisfy every rule in `bdd-standards.md`.
- **Weak:** §Bad sections in `.claude/skills/gherkin/examples.md` — pre-correction
  scenarios demonstrating typical failures.

When the first `docs/ux/*.md` feature file is committed, update `examples.md` to cite it
as the canonical strong-pass artefact.

*Calibration reference: `docs/skill-calibration-manifest.md` — gherkin row.*

## Standards and co-update partners

BDD quality rules are defined in `bdd-standards.md` (source: Cucumber/Gherkin specification). When those standards change, the following skills must be updated together: `gherkin-scenarios`, `gherkin-review`, `ralph-prompt-create`.
