# Skill Design Standards

This document defines quality standards for Claude Code skills in this project. It serves as:
- The reference rubric for the `/skill-review` command
- The canonical guide for `/skill-creator` when building new skills
- A calibration anchor when auditing existing skills for improvement

Skills reviewed under this rubric are the `.claude/skills/*/SKILL.md` files (and their sub-flow siblings).

---

## 12-Dimension Quality Rubric

Score each dimension **✅ Strong / ⚠️ Partial / ❌ Missing** by working through the binary checklist for that dimension. Count Y answers and apply the score mapping shown. Mark a question N/A only when it genuinely does not apply to the skill type under review (e.g. no file writes → ID Q2 is N/A); treat N/A as Y when counting. Do not apply holistic judgment — if a question cannot be answered Y or N from the skill text alone, answer N.

### TR — Trigger Clarity

- Q1. Does the `description` frontmatter field list ≥2 concrete example phrases that a user would type to invoke this skill?
- Q2. Does the scope exclude at least one related skill via an explicit "do not use when" clause or an unambiguously non-overlapping domain?
- Q3. Can the primary use case be understood from the `description` field alone, without reading the skill body?

**Score: 3 Y → ✅ | 2 Y → ⚠️ | 0–1 Y → ❌**

### IN — Input Specification

- Q1. Is there an explicit section or list that names all required inputs, or states "no inputs required" for zero-input skills?
- Q2. Are all optional inputs named with their default values stated?
- Q3. Is the behaviour for missing required inputs explicitly stated (AskUserQuestion, infer from X, or a named default)?

**Score: 3 Y → ✅ | 2 Y → ⚠️ | 0–1 Y → ❌**

### RC — Rubric Completeness

*For assessment skills (skills that score or review an artefact):*
- Q1. Does every criterion reference a specific observable element (named section, count, file path, command output) — not vague descriptors like "good quality" or "sufficient detail"?
- Q2. Do criteria have non-overlapping trigger conditions, such that no real-world case satisfies two criteria simultaneously?
- Q3. Does the skill state what to do when no criterion matches (fallback or stop rule)?

*For workflow/action skills (no assessment rubric):*
- Q1. Are success criteria explicitly enumerated (not just implied by the steps)?
- Q2. Are ≥1 failure conditions named explicitly?
- Q3. Is there a stated action for each named failure condition?

**Score: 3 Y → ✅ | 2 Y → ⚠️ | 0–1 Y → ❌**

### RS — Reproducibility

- Q1. Does every scoring threshold use a count, percentage, or named list — not "sufficient", "adequate", "appropriate", "reasonable", or "good enough"?
- Q2. Does every criterion reference an observable source: quoted text, file presence, command exit code, or named section heading?
- Q3. Does the skill contain none of these terms in scoring criteria: "several", "long-standing", "clearly", "appropriate", "sufficient", "reasonable", "adequate", "etc."?
- Q4. Where a range applies, is the boundary value stated explicitly (e.g. "≥3 items" not "multiple items")?

**Score: 4 Y → ✅ | 2–3 Y → ⚠️ | 0–1 Y → ❌**

### OA — Output Actionability

**Determine skill type before scoring. Apply the matching sub-checklist only.**

*Assessment skills* produce a scored report on an artefact (e.g. `adr-review`, `skill-review`, `ralph-prompt-review`):
- Q1. For every gap category, does the output template include a quoted evidence excerpt (direct quote from the artefact — not a description of it)?
- Q2. For every gap category, does the output template include exact fix text (the actual text to add — not "add a section about X")?
- Q3. Are all verdict options enumerated (not open-ended)?
- Q4. Does each verdict option have a stated selection rule (threshold or condition)?

*Workflow/action skills* execute steps with side effects (e.g. `smart-commit`, `adr-approve`, `fix-ci`):
- Q1. Does the output distinguish success from failure using distinct labelled blocks?
- Q2. Is the output format shown as a filled-in example — not a prose description of what it would look like?
- Q3. Are all completion states enumerated (e.g. success / partial / blocked / already-done)?
- Q4. Does each completion state have an explicit trigger condition?

*Dispatcher skills* route to sub-skills based on input (e.g. `gherkin`, `gcp`, `likec4`):
- Q1. Is the routing decision shown in the output (which sub-skill was selected and why)?
- Q2. Is the chosen sub-skill named explicitly in the output?
- Q3. Are all routing options enumerated?
- Q4. Does each routing option have a stated selection condition?

See `docs/skill-output-templates.md` for ready-made filled-in templates for each type.

**Score: 4 Y → ✅ | 2–3 Y → ⚠️ | 0–1 Y → ❌**

### OF — Output Format

- Q1. Does the skill include ≥1 explicit output example block or template (not just a prose description of what the output will look like)?
- Q2. Is the output structured (table, numbered list, or severity-grouped sections) — not prose paragraphs only?
- Q3. Is there a named verdict field with a finite set of possible values shown in the skill?

**Score: 3 Y → ✅ | 2 Y → ⚠️ | 0–1 Y → ❌**

### TE — Token Efficiency

- Q1. Does the skill contain any stable rule block spanning >20 consecutive lines that is NOT extracted to an external `.md` file referenced by path? (Y = no such block exists inline; N = at least one does)
- Q2. Are calibration examples referenced by file path or artefact identifier — not reproduced as inline prose? See `docs/skill-calibration-manifest.md` for the canonical per-skill path references.
- Q3. Does each major rule set or checklist appear ≤1 time in the skill file (no sections that duplicate each other)?
- Q1b. Does the skill contain any inline code block that meets ≥1 of the script extraction triggers (sleep/loop, JSON output contract, ≥3 CLIs chained, ≥3 conditional branches over external state, Python imports, or body >15 lines) that is NOT extracted to a `scripts/` file? (Y = no such block exists inline; N = at least one does)

**Score: 4 Y → ✅ | 2–3 Y → ⚠️ | 0–1 Y → ❌**

### EH — Edge Handling

- Q1. Does the skill state what to do when the input file or artefact is not found — with an explicit error message or named stop instruction?
- Q2. Does the skill state what to do when input is ambiguous — with a named resolution strategy (AskUserQuestion, infer from X, or default to Y)?
- Q3. Does the skill state what to do for a partial or empty artefact (not just a completely absent one)?
- Q4. Does every error path produce a named output (message text stated or referenced) rather than silently proceeding?

**Score: 4 Y → ✅ | 2–3 Y → ⚠️ | 0–1 Y → ❌**

### ID — Idempotency

*(Mark N/A where the skill type makes a question inapplicable; N/A counts as Y.)*

- Q1. Does the skill state what happens when run twice on the same unchanged artefact (identical output, or deduplication mechanism named)?
- Q2. Does every file-write step include an existence check before writing, or an explicit "overwrite is intentional" statement? *(N/A if skill writes no files)*
- Q3. Does every GitHub side effect use an idempotency mechanism: HTML comment marker, `--edit` flag, or existence check before posting? *(N/A if skill has no GitHub side effects)*

**Score: all applicable Y → ✅ | ≥1 applicable N → ⚠️ | Q1=N or all applicable N → ❌**

### SC — Standards Currency

- Q1. Does the skill name ≥1 source or rationale for its primary scoring criteria (e.g. cites an ADR, external specification, or corpus analysis)?
- Q2. Does the skill list the other skills that share the same domain standard and must be co-updated when criteria change?
- Q3. Are shared rubrics referenced from a single canonical source — not duplicated across skills?

**Score: 3 Y → ✅ | 2 Y → ⚠️ | 0–1 Y → ❌**

### CV — Calibration

- Q1. Does the skill name ≥1 strong (passing) calibration example, referenced by file path or artefact identifier — not described inline? See `docs/skill-calibration-manifest.md` for the canonical per-skill references.
- Q2. Does the skill name ≥1 weak or pre-requirement calibration example, referenced by file path or artefact identifier?
- Q3. Run `Glob <cited-path>` for each named calibration artefact before answering. Y if every cited path returns ≥1 match. N if any cited path returns no match, or if no path was cited at all. Mark N/A (counts as Y) only when the skill has no calibration section whatsoever.

**Score: 3 Y → ✅ | 2 Y → ⚠️ | 0–1 Y → ❌**

### CO — Coherence

- Q1. Does the skill reference shared rubrics from their canonical source — not define them inline when they exist in another skill or doc?
- Q2. If this skill shares a standard with another skill, is it listed in the relationship map in `docs/skill-design-standards.md`? *(N/A if skill shares no standards)*
- Q3. Do the skill's scoring conventions (✅/⚠️/❌, verdict labels, severity names) match the project standard defined in the Scoring conventions section below?

**Score: 3 Y → ✅ | 2 Y → ⚠️ | 0–1 Y → ❌**

### Scoring calibration

| Score | Meaning | Implication |
|-------|---------|-------------|
| ✅ Strong | Criterion fully met; evidence is unambiguous | No action needed |
| ⚠️ Partial | Criterion partially met; identifiable gap exists | Improvement recommended |
| ❌ Missing | Criterion absent or so vague it gives no useful guidance | Fix required |

### Overall verdict

| Verdict | Threshold |
|---------|-----------|
| **Optimised** | All 12 ✅, or at most 2 ⚠️ in low-impact dimensions (ID, SC, CV) |
| **Needs improvement** | One or more ❌, or three or more ⚠️ in any dimension |
| **Major revision** | Multiple ❌ in RC, RS, OA, or OF (the dimensions that determine whether the skill reliably produces useful output) |

---

## Token Efficiency Techniques

These five techniques reduce skill prompt size without reducing output quality. Apply them in order of impact.

### 1. Information density audit

Flag prose paragraphs that restate information already in the rubric table. Convert to bullet lists or table rows. A sentence like "When evaluating completeness, check whether each criterion is present" adds no information beyond the table row itself.

Tool: count lines in each "step" of the skill; steps with >15 prose lines are candidates for compression.

### 2. Reference extraction

Any stable rule set >1 KB that is likely to be read in full belongs in an external `.md` file. The skill references the file with a `Read` call; Claude reads it once per session.

Pattern already used by:
- `gherkin` → `bdd-standards.md`
- `likec4` → `dsl-reference.md`

Apply to: any skill with an embedded rule catalogue (STRUCT-NNN, RULE-NNN style) or a >20-item checklist.

### 3. Calibration by reference

Instead of embedding a worked example (200+ words), name the exemplar:

> "See `prompts/phase-11-bug-fixes.md` as a ✅ Strong example of dimension C."

Reduces prompt size. Maintains calibration anchor. Requires the referenced file to exist and remain stable.

### 4. Conditional loading (dispatcher pattern)

A skill that covers multiple distinct modes (generate vs. review; deploy vs. recover) should split into:
- A dispatcher skill that reads the mode and routes
- Sub-flow skill files loaded only for the active mode

Pattern already used by: `gherkin`, `likec4`, `gcp`.

Apply to: any skill with an `if mode == X / elif mode == Y` branching structure that causes >50% of the skill to be irrelevant for any given invocation.

### 5. Ternary → binary compression

Where ⚠️ Partial produces no different user action than ✅ Strong (i.e. both result in "no change needed"), collapse to binary. This reduces decision complexity and scoring prose.

**Keep ternary** when Partial implies a specific improvement recommendation distinct from both Strong and Missing.

**Collapse to binary** for mechanical pass/fail checks: file exists, command runs, section present.

---

## Script Extraction Standards

These rules define when inline code in a SKILL.md should become a `scripts/` file rather than an inline bash/python block. They extend the TE dimension's Q1 rule (prose extraction) to cover executable logic.

### Extract to `scripts/` when ANY of these apply

| Trigger | Rationale |
|---------|-----------|
| Contains `sleep` or a polling loop | Cannot run as a single Bash tool call |
| Outputs JSON/TSV that Claude parses in the next step | Decouples data-gathering from model reasoning; independently testable |
| Chains ≥3 external CLIs in sequence | Inline multi-tool pipelines are fragile |
| Defines a function or contains ≥3 conditional branches over external state | Decision logic across external state belongs in code |
| Same operation appears in ≥2 skill steps | Avoids duplication |
| Uses Python `import` statements | Imports signal non-trivial logic |
| Body exceeds 15 lines | Crosses readable-at-a-glance threshold |

### Keep inline when ALL of these apply

- Single command or pipeline of ≤2 tools — no loop, no functions, no `sleep`
- Produces a scalar value (string, exit code, line count) — not JSON for parsing
- Not reused in another step
- Body ≤15 lines

**Key distinction:** *Inline code is an invocation pattern Claude adapts; a script is a fixed algorithm Claude executes.* If a future step's behaviour depends on parsing the output, it is data — data collection belongs in scripts.

### Naming and structure conventions

- Location: `scripts/` within the skill directory
- Bash: `kebab-case.sh`; Python: `kebab-case.py`
- Name by action/output, not step number (`detect-gcp-config.sh` not `step-2.sh`)
- Header comment block: purpose, usage, args, stdout format, exit codes
- Python: always `uv run python scripts/name.py` — never bare `python3`

### Invocation conventions in SKILL.md

- Define `SKILL_DIR=.claude/skills/<name>` once at the top of the skill
- Call as `bash "$SKILL_DIR/scripts/script-name.sh" [args]`
- Explicitly state expected exit codes and what Claude does with each

### Output contract for scripts (one type per script)

| Output type | Format | Progress channel |
|-------------|--------|-----------------|
| Structured data for Claude to reason over | JSON | stderr |
| Terminal-state check | Status string | stderr |
| Side-effect only | Exit code | — |

**Canonical invocation-documentation exemplar:** `.claude/skills/fix-ci/SKILL.md` scripts table — use its format when documenting a skill's scripts in SKILL.md.

---

## Skill Authoring Guide

New skills must use binary criteria from the start — not prose descriptions that require personal judgment. This applies to every scoring dimension, verdict threshold, and decision rule in the skill.

### Quick-start authoring aids

| What you need | Where to find it |
|---|---|
| Output template (assessment / workflow / dispatcher) | `docs/skill-output-templates.md` |
| Calibration example paths for your skill | `docs/skill-calibration-manifest.md` |
| Frontmatter field reference | §SKILL.md frontmatter requirements below |
| Scoring convention | §Scoring conventions below |

### RS checklist for new skill authors

Before shipping a new skill, verify every scoring or decision criterion passes the RS checklist:

- Q1. Does every threshold use a count, percentage, or named list — not "sufficient", "adequate", "appropriate", "reasonable", or "good enough"?
- Q2. Does every criterion reference an observable source: quoted text, file presence, command exit code, or named section heading?
- Q3. Does the skill contain none of these terms in scoring criteria: "several", "long-standing", "clearly", "appropriate", "sufficient", "reasonable", "adequate", "etc."?
- Q4. Where a range applies, is the boundary value stated explicitly (e.g. "≥3 items" not "multiple items")?

A skill that fails any RS question scores ⚠️ or ❌ on the RS dimension when reviewed by `/skill-review`. Fix it before shipping.

### Why binary criteria matter

In the 2026-04-10 audit cycle, three batch runs on the same 28 unchanged skills produced different verdicts for `ralph-guardrails`, `ralph-preflight`, and `readme-check`. The root cause was subjective language in dimension descriptions ("sufficient", "appropriate") that required personal judgment. Binary checklists eliminate this variance — see the `## Research basis` section for the empirical grounding.

---

## Scoring conventions (project standard)

To keep skills coherent with each other, use these scoring systems:

| Use case | Scoring convention |
|----------|-------------------|
| Dimension scoring (rubrics) | ✅ Strong / ⚠️ Partial / ❌ Missing |
| Severity of findings | CRITICAL / HIGH / MEDIUM / LOW |
| Overall verdict | Skill-specific but must be enumerated (not open-ended) |
| Numeric rubrics (corpus only) | 0=Missing, 1=Partial, 2=Strong |

Do **not** invent new scoring schemes. If a skill uses a different convention, flag as a CO (coherence) gap.

---

## SKILL.md frontmatter requirements

Full reference: [Claude Code Skills documentation](https://code.claude.com/docs/en/skills#frontmatter-reference)

All fields are optional except `description` (strongly recommended). Only document fields you actually use.

| Field | Constraints | Notes |
|-------|-------------|-------|
| `name` | Lowercase letters, numbers, hyphens only; max 64 chars | Defaults to directory name if omitted; becomes the `/slash-command` |
| `description` | **≤250 characters** (truncated in skills listing) | Primary trigger signal; front-load the key use case |
| `argument-hint` | Free text | Shown during autocomplete; set whenever skill uses `$ARGUMENTS` |
| `disable-model-invocation` | `true` / `false` (default `false`) | `true` = user-only invocation; use for side-effect workflows (deploy, commit, post) |
| `user-invocable` | `true` / `false` (default `true`) | `false` = hidden from `/` menu; use for background knowledge skills |
| `allowed-tools` | Space-separated tool names | Grants permission without per-use approval when skill is active |
| `model` | Model ID string | Overrides session model for this skill |
| `effort` | `low` / `medium` / `high` / `max` | `max` requires Opus 4.6; overrides session effort level |
| `context` | `fork` | Runs skill in an isolated subagent context |
| `agent` | `Explore`, `Plan`, `general-purpose`, or custom agent name | Subagent type to use when `context: fork` is set |
| `hooks` | YAML hooks config | Skill lifecycle hooks; see hooks documentation |
| `paths` | Comma-separated glob patterns | Limits auto-activation to matching file paths |
| `shell` | `bash` (default) / `powershell` | Shell for inline `!` commands in skill body |

Do **not** add `version` — it is not a supported frontmatter field.

---

## Platform Structure Requirements

These are mechanically verifiable requirements defined by the Claude Code platform. They are checked as a pre-flight step (Step 1b in `/skill-review`) **before** the 12-dimension quality rubric. Failures are reported as structural issues, separate from dimension scores.

Source: [Claude Code Skills documentation](https://code.claude.com/docs/en/skills)

### Pre-flight checks (P1–P6)

| Check | How to verify | Fail condition | Impact if missed |
|-------|--------------|----------------|-----------------|
| **P1** SKILL.md line count | `wc -l SKILL.md` | >500 lines | Exceeds platform limit; TE and context load degrade |
| **P2** description length | Count chars in `description` value | >250 characters | Truncated in skills listing — Claude loses trigger keywords |
| **P3** name field constraints | Inspect `name` frontmatter | Contains uppercase, spaces, or non-hyphen special chars; or >64 chars | Slash command may fail or behave unexpectedly |
| **P4** invocation control fitness | Classify skill type; check `disable-model-invocation` | Task/workflow skill without `disable-model-invocation: true` | Claude auto-triggers side-effect workflows without user intent |
| **P5** argument-hint presence | Grep for `$ARGUMENTS` in SKILL.md | `$ARGUMENTS` present but `argument-hint` absent from frontmatter | Autocomplete gives no guidance on expected arguments |
| **P6** supporting files referenced | List files in skill dir; check SKILL.md for each filename | File in dir not mentioned in SKILL.md | File silently ignored — Claude never loads it |

### Invocation control guide

Use this table to determine whether `disable-model-invocation` is required (P4 check):

| Skill type | `disable-model-invocation` | `user-invocable` |
|------------|--------------------------|-----------------|
| Reference content — conventions, patterns, domain knowledge | `false` (default) | `true` (default) |
| Task/workflow — side effects, deploys, commits, posts to external services | **`true`** | `true` (default) |
| Background knowledge — not a meaningful user action | `false` (default) | **`false`** |

---

## Calibration examples

### Strong examples (reference for quality)

| Skill | Strong dimensions | Notes |
|-------|------------------|-------|
| `ralph-prompt-review` | TR, RC, RS, OA, OF, CV | Gold standard for rubric completeness and calibration anchors |
| `issue-readiness-check` | TR, RC, OA, OF, EH | Decision table and idempotency markers are best-in-class |
| `gherkin` | TE, CO | Best example of reference extraction and dispatcher pattern |

### Skills needing improvement (reference for gap patterns)

| Skill | Weak dimensions | Typical gap |
|-------|----------------|-------------|
| `adr-review` | IN, EH | Inputs not listed; no handling for ADR not found |
| `insights-review` | RC, RS, OA, OF | No formal rubric; workflow-only; output format unspecified |
| `adr-new` | RC, CV | Minimal quality gates; relies entirely on `adr-review` afterward |

---

## Relationship map (shared standards)

When a standard changes, these skill pairs must be co-updated:

| Standard | Skills sharing it |
|----------|------------------|
| R1–R9 issue rubric | `issue-refine`, `issue-readiness-check` |
| 10-dim phase rubric | `ralph-prompt-review`, `corpus-sync` |
| ADR structure rules | `adr-review`, `adr-refine`, `adr-check`, `adr-consistency` |
| BDD standards | `gherkin` (both sub-flows) |
| LikeC4 DSL rules | `likec4` (both sub-flows) |
| UK English rule | `adr-review`, `readme-check`, `adr-refine` |
| Platform structure requirements (P1–P6) | `skill-review` (Step 1b); source: `docs/skill-design-standards.md` |
| 12-dimension skill quality rubric | `skill-review`, `skill-improver` — update together when checklist wording changes |

---

## Research basis

The binary checklist format for each dimension is grounded in two bodies of work. This section is preserved so that future reviewers can evaluate whether the approach still holds as the skill fleet evolves.

### G-EVAL (Liu et al., EMNLP 2023)

*G-EVAL: NLG Evaluation using GPT-4 with Better Human Alignment*

Key finding: decomposing LLM evaluation into a chain of fine-grained yes/no questions significantly improves inter-rater agreement between independent model-judges, compared to holistic Likert scoring. When evaluators are given explicit binary criteria rather than open-ended rubrics, the Spearman correlation with human judgments increases substantially.

**Application here:** each dimension's prose description has been replaced with a numbered binary checklist. Scores map mechanically from Y-counts, eliminating the "does this count as sufficient?" meta-judgment that caused variance between audit runs.

### Analytic vs. holistic rubrics (educational assessment)

Established principle: analytic rubrics — where each dimension is scored against explicit, enumerated criteria — produce significantly higher inter-rater reliability (Cohen's κ) than holistic rubrics, where a single overall impression drives scoring.

Key reference: Brookhart (2013), *How to Create and Use Rubrics for Formative Assessment and Grading*. This is the standard reference in the rubric design literature for the analytic/holistic distinction.

**Application here:** the original 12-dimension table was a holistic rubric (one prose description per dimension). The checklist format converts it to an analytic rubric, where each dimension decomposes into independently verifiable sub-criteria.

### Claude Code Skills platform documentation

URL: https://code.claude.com/docs/en/skills

Authoritative source for: all supported frontmatter fields and their constraints, the 500-line SKILL.md limit, the 250-character description truncation threshold, invocation control semantics (`disable-model-invocation`, `user-invocable`), supporting files directory structure, `context: fork` isolation, and string substitution variables (`$ARGUMENTS`, `${CLAUDE_SKILL_DIR}`, etc.).

**Application here:** the Platform Structure Requirements section (P1–P6 pre-flight checks) and the complete frontmatter reference table are derived directly from this documentation. When the platform adds new fields or changes limits, update those sections and re-run `/skill-review --all` to surface any new gaps.

### Why this matters for skill audits

The 2026-04-10 audit cycle ran the same 28 unchanged skills three times and produced different verdicts for `ralph-guardrails`, `ralph-preflight`, and `readme-check` between v2 and v3. Those skills did not change — the scoring did. That variance is the specific failure mode that the binary checklist format is designed to eliminate.
