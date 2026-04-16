---
name: skill-review
description: >
  Review skills against the 12-dimension quality rubric. Produces scored table, evidence-backed
  findings, token estimate, and top-3 improvements. Triggers: 'review skill', 'audit skill',
  'how good is X skill', '/skill-review'.
argument-hint: "<skill-name or --all>"
disable-model-invocation: true
allowed-tools: AskUserQuestion, ToolSearch, Read, Glob, Bash, Bash(bash .claude/skills/skill-review/scripts/preflight-check.sh:*)
---

# Skill Review

Reviews a Claude Code skill against the project's 12-dimension quality rubric, returning a scored
report with evidence, token estimate, and prioritised improvements.

**Do not use when** — reviewing a PR (use `/code-review`), reviewing a regular markdown
document (use `/readme-check`), auditing an ADR (use `/adr-review`), rewriting a skill
wholesale (use `/skill-improver`), or validating a phase prompt (use `/ralph-prompt-review`).
This skill scores a single `SKILL.md` against a fixed rubric and optionally edits only the
sections corresponding to ❌ dimensions — it does not rewrite untouched prose, generate
new skills, or apply fixes to dimensions that scored ✅ or ⚠️.

## Inputs

- **Required:** skill name (e.g. `adr-review`), partial name (e.g. `adr`), or skill file path
- **Optional:** `--all` to audit all skills in batch mode
- **If empty:** ask which skill to review (handled in Step 1)

## Step 1 — Identify the target skill

Check `$ARGUMENTS`:

- **Skill name given** (e.g. `adr-review`, `smart-commit`): resolve to
  `.claude/skills/<name>/SKILL.md`.
- **Partial name given** (e.g. `adr`): run `Glob .claude/skills/<name>*/SKILL.md` to find candidates;
  if multiple match, fetch `AskUserQuestion` (`ToolSearch select:AskUserQuestion`) and ask which one.
- **No args given**: ask:
  > "Which skill would you like me to review? Provide the skill name (e.g. `adr-review`, `smart-commit`)."

If the resolved path does not exist: report "Skill not found at `.claude/skills/<name>/SKILL.md`" and stop.

**Partial or empty artefact handling:**
- If sub-flow files are absent, proceed with SKILL.md only — no error.
- If SKILL.md itself is empty, emit: `ERROR: [skill-name]/SKILL.md is empty — nothing to review.` and stop.

## Step 1b — Platform pre-flight (P1–P6)

Run the mechanical platform checks defined in `docs/skill-design-standards.md`
§Platform Structure Requirements. These must pass before the 12-dimension rubric is
applied. Failures here are structural, independent of dimension scores.

```bash
bash .claude/skills/skill-review/scripts/preflight-check.sh <skill-name>
```

Parse the JSON result:

- `overall: "PASS"` → report the per-check table in Step 5 under "Platform pre-flight"
  and continue to Step 2.
- `overall: "FAIL"` → still run Steps 2–5, but the Verdict must be at least **Needs
  improvement** regardless of dimension scores (structural gaps block Optimised).
- Exit code 2 → report "Skill not found" and stop.

P4 emits `WARN` (not a fail counter) when the description contains side-effect verbs
and `disable-model-invocation` is not `true` — relay the warning to the user; treat
the status as ⚠️ in the summary table.

## Step 2 — Read the skill

Read in this order:

1. The target skill's `SKILL.md`.
2. Any sub-flow files in the same directory — read all.
3. Any external reference docs named in the skill — read to estimate their size.

## Step 3 — Score 12 dimensions

The canonical checklist (per-dimension binary questions) lives in
`docs/skill-design-standards.md` §Dimension rubric. Read that file at invocation time;
do not attempt to score from memory or from the table below.

For each dimension, evaluate against its binary checklist. Count Y answers and apply
the standards file's score mapping. If a question cannot be answered Y or N from the
skill text alone, answer N.

| ID | Dimension | Q count | Canonical source |
| --- | --- | --- | --- |
| TR | Trigger Clarity | 3 | `docs/skill-design-standards.md` §TR |
| IN | Input Specification | 3 | `docs/skill-design-standards.md` §IN |
| RC | Rubric Completeness | 3 | `docs/skill-design-standards.md` §RC |
| RS | Reproducibility | 4 | `docs/skill-design-standards.md` §RS |
| OA | Output Actionability | 4 | `docs/skill-design-standards.md` §OA |
| OF | Output Format | 3 | `docs/skill-design-standards.md` §OF |
| TE | Token Efficiency | 4 | `docs/skill-design-standards.md` §TE |
| EH | Edge Handling | 4 | `docs/skill-design-standards.md` §EH |
| ID | Idempotency | 3 | `docs/skill-design-standards.md` §ID |
| SC | Standards Currency | 3 | `docs/skill-design-standards.md` §SC |
| CV | Calibration | 3 | `docs/skill-design-standards.md` §CV |
| CO | Coherence | 3 | `docs/skill-design-standards.md` §CO |

For every ⚠️ or ❌ dimension, record:
1. **Evidence** — a direct quote from the skill file (or "This section is absent.")
2. **Fix** — the concrete text or structure to add

## Step 4 — Estimate token footprint

```bash
wc -l .claude/skills/<name>/SKILL.md
```

Run the same for any sub-flow files and named external docs. Report:

```
Token estimate
  SKILL.md:          ~<N> lines → ~<N> tokens
  Sub-flows:         ~<N> lines → ~<N> tokens
  External docs:     ~<N> lines → ~<N> tokens  (read per invocation)
  Total per invoke:  ~<N> tokens
```

Rough conversion: 1 line ≈ 10 tokens (conservative estimate for skill prose).

Flag if total exceeds 3,000 tokens as a TE concern.

## Step 5 — Write the report

Output in this exact order:

### Summary table

```
## Skill Review: <name>

| ID | Dimension           | Score | One-line finding                                    |
|----|---------------------|-------|-----------------------------------------------------|
| TR | Trigger Clarity     | ✅    | Trigger phrases listed; no overlap with peers       |
| IN | Input Specification | ⚠️    | Required inputs implied, not explicitly listed      |
...
```

### Per-dimension findings

Write a block **only for ⚠️ and ❌** — skip ✅. Format each as:

```
#### <ID> — <Dimension Name> <emoji>

**Evidence:** "<exact quote>" or "This section is absent."

**Fix:**
<concrete text to add, formatted as it would appear in the skill>
```

### Token footprint

Show the estimate from Step 4.

### Top 3 improvements

List the three highest-impact gaps in priority order. Score each non-✅ dimension with:

```text
severity   — ❌ = 3, ⚠️ = 1
frequency  — High (invoked daily; triggers include one or more of:
             "ralph-", "adr-", "commit", "pipeline", "preflight") = 2
           — Normal (everything else) = 1
priority   = severity × frequency
```

Sort descending by `priority`; ties broken by dimension ID order
(TR < IN < RC < RS < OA < OF < TE < EH < ID < SC < CV < CO). Take the top three.

Rule: any ❌ in the high-impact set (RC, RS, OA, OF) ranks above all ⚠️ regardless of
frequency — these four dimensions have an implicit `severity = 4` override when failing.

### Verdict

```
**Verdict:** Optimised / Needs improvement / Major revision
```

- **Optimised** — all 12 ✅, or at most 2 ⚠️, and every ⚠️ is in the low-impact set
  (ID, SC, CV).
- **Needs improvement** — ≥1 ❌ in any dimension, **or** ≥3 ⚠️ in any combination.
- **Major revision** — ≥2 ❌ in the high-impact set (RC, RS, OA, OF), **or** ≥5 ⚠️
  across all dimensions.

## Step 6 — Seal all ❌ dimensions

After the report, apply fixes for every ❌ dimension in sequence without asking between each one:

1. Work through each ❌ dimension using the evidence + fix text from Step 5.
2. Apply with `Edit`.
3. After each edit, re-read the modified section and confirm the dimension would now score ✅ before moving to the next ❌.
4. Do not touch dimensions that scored ✅.

Once all ❌ are cleared, ask:

> "All ❌ dimensions are resolved. Would you like me to work through the ⚠️ dimensions as well, starting with the highest-impact gaps?"

---

## Idempotency

- **Read-only modes (Steps 1–5):** safe to re-run; no side effects.
- **Step 6 (seal ❌):** each fix is applied with `Edit` which is exact-match idempotent —
  re-running after a successful seal is a no-op because the `old_string` no longer exists.
  If an edit fails mid-sequence, the skill halts; re-running resumes at the next unresolved
  ❌ without reverting prior fixes.
- Batch audit mode (`--all`) is also safe to re-run — each sub-agent produces a report for
  its own skill; the aggregation overwrites the dated audit file deterministically.

## Calibration

- **Strong:** `.claude/skills/adr-check/SKILL.md` — compact, single-purpose, cites its
  canonical rules file, has named edge cases and an idempotency statement. A review of
  this file should score at most 1 ⚠️.
- **Weak:** `.claude/skills/ralph-prompt-create/SKILL.md` — long (>500 lines), multiple
  in-lined rules that should live in sibling files, mixes calibration examples with step
  logic. A review of this file should flag TE, RC, and at least one CV gap.

See `docs/skill-calibration-manifest.md` §Skill meta-skills for the canonical pair.

## Standards

- **Rubric source:** `docs/skill-design-standards.md` §Dimension rubric — canonical list of
  dimensions and their binary checklist questions. Do not duplicate the questions in this
  skill; fetch them at invocation time.
- **Scoring conventions:** `docs/skill-design-standards.md` §Scoring (✅ Strong / ⚠️ Partial
  / ❌ Missing). The `PASS/WARN/FAIL/SKIP` verdict enum used by `devcontainer-check` is a
  different, non-overlapping convention for health-check output cells.
- **Verdict thresholds:** `docs/skill-design-standards.md` §Verdict — Optimised / Needs
  improvement / Major revision.

---

## Batch audit mode

**Trigger:** user says "audit all skills", "review all skills", or passes `--all` as argument.

In this mode:
1. Run `Glob .claude/skills/*/SKILL.md` to list all skills.
2. For each skill, run this review as a **sub-agent** (via the `Agent` tool) — one agent per skill, all launched in parallel.
3. Aggregate results into a summary table.
4. Offer to save to `docs/skill-reviews/audit-<YYYY-MM-DD>.md`.

---

## Co-update partners

Related skills that share the same rubric and must be kept in sync. The canonical rubric
itself lives in `docs/skill-design-standards.md` (see §Standards above) — when that file
changes, re-verify each co-update partner below:

- **skill-improver** — applies fixes identified by this review; must use the same
  ✅ / ⚠️ / ❌ scoring and the same dimension IDs (TR, IN, RC, RS, OA, OF, TE, EH, ID,
  SC, CV, CO).
