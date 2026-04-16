---
name: ralph-prompt-review
description: >
  Review a ralph-loop phase prompt against a 10-dimension quality model. Surfaces gaps with
  evidence quotes and applies targeted fixes. Triggers: 'review ralph prompt',
  'audit phase prompt', 'check my phase', '/ralph-prompt-review'.
argument-hint: "<prompt-file-or-dir> [--post-run]"
allowed-tools: AskUserQuestion, ToolSearch, Read, Glob, Grep, Edit, Bash
---

# Ralph Prompt Review

Reviews a ralph-loop phase prompt against a 10-dimension quality model, returning a scored report with evidence-backed findings and specific fix suggestions.

> **Two rubric systems — do not mix them:**
> - **Pre-run mode (Steps 1–5):** 10-dimension quality rubric (C, S, D, B, K, V, P, T, Z, CL) — assesses whether the prompt is ready to run.
> - **Post-run mode (`--post-run`, Steps A–E):** concern score tally by Q1–Q12 — analyses concerns the agent raised *during* execution.
> These serve different lifecycle moments. A post-run concern score is not a pre-run quality score.

## Step 1 — Identify the target

Check invocation args:

- **File path given** (e.g. `prompts/completed/phase-22-telemetry.md` or `prompts/completed/phase-22/`): use it directly.
- **Phase number given** (e.g. "phase 6", "phase-06", "22"): run `Glob prompts/phase-<N>*` to resolve both a file and a directory match.
- **Ambiguous or no args**: fetch `AskUserQuestion` (`ToolSearch select:AskUserQuestion`), then ask:
  > "Which phase prompt would you like me to review? Provide a file path, directory path, or phase number."

**Error handling:** If the resolved file or directory does not exist, emit: `ERROR: Target not found at [path]. Check the path and try again.` and stop. Do not proceed with a missing input.

**`--post-run` flag:** If `--post-run` appears in args, skip Steps 1–5 (pre-run mode) entirely and jump directly to Post-run mode (Step A). The `--post-run` flag is mutually exclusive with pre-run scoring — do not score the 10 dimensions when this flag is present.

**Idempotency:** Re-running on an unchanged prompt file produces the same scores — this skill is idempotent on read-only inputs. Running after fixes are applied will show improved scores — this is expected, not a defect.

## Step 2 — Read for calibration

Before scoring, read the schema that defines what a complete phase prompt must contain:
- `.claude/skills/ralph-prompt-create/SKILL.md` — sections 1–7 define the required structure and content for every section.

Then read the target:
- **Single file** (`prompts/phase-NN-*.md`): read the full file.
- **Pipeline directory** (`prompts/phase-NN/`): read `00-pipeline.md` and every numbered step file (`01-*.md`, `02-*.md`, etc.). A pipeline phase is evaluated as a whole — the manifest provides the dependency graph; the step files provide the behavioural detail. Score the combination, not just the manifest.

## Step 3 — Score 10 dimensions

Score each dimension **✅ Strong / ⚠️ Partial / ❌ Missing**.

| ID | Dimension | What "Strong" looks like |
|----|-----------|--------------------------|
| **C** | Context / Rationale | Opening paragraph explains *why* this phase exists, what problem it solves, and how it builds on prior work. Prior phases named with status (deployed / superseded / code-complete). |
| **S** | Scope Boundaries | Explicit "must NOT be modified" file list — specific paths, not vague categories. Out-of-scope items named, not merely implied. |
| **D** | Deliverable Specification | Every output file in a markdown table with full path + Create/Update/Delete. Nothing implied only in prose — one row per file. No unresolved `[VERIFY...]` markers remain — all cautious inclusions have been confirmed or removed. |
| **B** | Behavioural Precision | Function signatures with typed parameters and return shapes. HTTP routes with full request/response JSON including error shapes. UI: state transitions described step by step. Data: schema fields named with types (not just "a user object"). |
| **K** | Constraints | Security rules, tooling choices (e.g. "OpenTofu not Terraform"), backwards compat rules, model choices — all explicitly stated in a Constraints section, not scattered in prose. No unresolved `[DIAGRAM UPDATE REQUIRED]` or `[MANUAL STEP...]` markers remain. |
| **V** | Verification Criteria | Per-deliverable runnable shell commands with expected output shown. Not prose like "verify it works" — actual `node --check`, `tofu validate`, `grep -n`, or `curl` commands. Flag any `grep -c` check on a string that may appear inside a loop construct: this counts call sites, not runtime invocations, and will always return a fixed count regardless of how many items are processed at runtime. |
| **P** | Dependencies / Prerequisites | "Read before starting" file list. Prior-phase deliverables named if required. Cross-phase dependencies explicit, not assumed. |
| **T** | Testability | Test files appear as rows in the deliverables table. Specific test case names/assertions described, not just "add tests". The full suite command (`<project-defined full-suite command>`) is present. |
| **Z** | Completion Signal | DONE is gated on an explicit numbered checklist (≥4 items covering deliverables, validation, and no-stale-references checks). Not an unconditional `print DONE`. |
| **CL** | Concerns Log | Section 6 (Loop execution strategy) contains a `### Concerns log` block instructing the agent to append to `prompts/phase-NN/concerns.md` for contradictions, missing information, and assumptions. All three categories are named. The instruction says to proceed without stopping. |

### Scoring calibration

See `docs/skill-design-standards.md` for full dimension definitions and Strong / Partial / Missing scoring thresholds.

**Inline threshold summary** (operative when the external file is unavailable):
- **✅ Strong** — dimension fully satisfied; no material gaps.
- **⚠️ Partial** — dimension present but incomplete; a targeted fix would close the gap.
- **❌ Missing** — dimension absent or so incomplete it cannot guide implementation.

**Stop condition:** If ≥3 dimensions score ❌, stop after producing the report. Do not apply fixes until the user explicitly confirms they want to proceed — the prompt may need substantial restructuring rather than targeted edits.

See also `evals/evals.json` in this skill directory for calibration test cases and
expected outputs.

For every ⚠️ or ❌, provide:
1. **Evidence**: a direct quote (or the absence) from the file that justifies the score.
2. **Fix**: the actual text or structure to add — not "add more detail".

## Step 4 — Write the report

Output in this exact order, using markdown.

### Summary table

```
| Dim | Dimension             | Score | One-line finding                                  |
|-----|-----------------------|-------|--------------------------------------------------|
| C   | Context / Rationale   | ✅    | Prior phases named, motivation clear              |
| S   | Scope Boundaries      | ⚠️    | "must NOT" list present but infra files missing  |
| D   | Deliverable Spec      | ✅    | All files in table with Create/Update            |
| B   | Behavioural Precision | ❌    | No function signatures or HTTP contracts         |
| K   | Constraints           | ✅    | Security and tooling rules explicit              |
| V   | Verification Criteria | ⚠️    | Self-verification section is prose, no commands  |
| P   | Dependencies          | ✅    | Read-before-starting list present                |
| T   | Testability           | ❌    | No test files in deliverables table              |
| Z   | Completion Signal     | ⚠️    | DONE present but no checklist                    |
| CL  | Concerns Log          | ❌    | No concerns log instruction in Section 6         |
```

### Per-dimension findings

Write a finding block **only for ⚠️ and ❌ dimensions** — skip ✅ ones. The user only needs to act on gaps.

Format each block as:

```
#### <ID> — <Dimension Name> <score emoji>

**Evidence:** "<exact quote from the file>" or "This section is absent."

**Fix:**
<the concrete text or structure to add, formatted as it would appear in the prompt>
```

### Overall verdict

Choose one, with a one-sentence rationale:

- **Ready to run** — all 10 ✅, or at most two ⚠️ with low-risk gaps (e.g. docs-only deliverables with light verification)
- **Needs improvement** — one or more ❌, or three or more ⚠️
- **Not ready** — multiple ❌ in B, V, or T (the dimensions that most determine whether an agent can implement and verify the work correctly); or any unresolved `[VERIFY...]` / `[DIAGRAM UPDATE REQUIRED]` / `[MANUAL STEP...]` markers in the generated files

## Step 5 — Offer fixes

After the report, ask:

> "Would you like me to apply the fixes I suggested? I'll make targeted edits — I won't touch sections that scored ✅."

If yes: apply each fix with `Edit`. Edit only the lines or sections that scored ⚠️ or ❌. After editing, confirm which dimensions improved.

## Post-run mode (`--post-run`)

Invoke after a pipeline has completed (or been abandoned) to review the concerns file and produce a corpus improvement report. This is a separate review moment from the pre-run mode above.

**Trigger:** user says "review concerns for phase N", "post-run review phase N", or passes `--post-run` as an argument.

### Step A — Locate concerns file

```bash
ls prompts/phase-<N>/concerns.md
```

If the file does not exist or is empty: report "No concerns raised during this run — concern score: 0" and stop. This is a positive signal.

### Step B — Tally concern score

Count entries by category:

```bash
grep -c "Category:\*\* contradiction" prompts/phase-<N>/concerns.md || echo 0
grep -c "Category:\*\* missing-info"  prompts/phase-<N>/concerns.md || echo 0
grep -c "Category:\*\* assumption"    prompts/phase-<N>/concerns.md || echo 0
```

Concern score = `(contradictions × 3) + (missing-info × 2) + (assumptions × 1)`.

### Step C — Categorise by Q1–Q12

For each concern entry, read its `**Prompt section:**` field and map it to the Q number from `ralph-prompt-create` that governs that section (e.g. "Deliverable 2 — API shapes" → Q5, "Constraints" → Q8, "Self-verification" → Q10).

### Step D — Write the post-run report

```
Phase <N> — Post-run Concerns Report

Concern score: <N>  (contradiction=3, missing-info=2, assumption=1)
  Contradictions: <N>
  Missing info:   <N>
  Assumptions:    <N>

By question:
  Q<N> — <question name>: <count> concern(s)
    • [category] <one-line summary of what the agent encountered>
    • ...

Corpus update recommendations:
  • Q<N> exemplar for <phase-type>: <specific text to add or strengthen>
  • ...

Suggested run record entry:
  concern_score: <N>
  concerns_file: "prompts/phase-<N>/concerns.md"
```

### Step E — Update run record

Offer to append the concern score to the latest entry in `prompts/phase-runs.yaml` for this phase. If the file does not exist yet, offer to create it with the current run as the first entry using `outcome: success` (the human corrects the outcome if needed).

## Standards

The 10-dimension quality model (C, S, D, B, K, V, P, T, Z, CL) is derived from `docs/skill-design-standards.md`. That file is the canonical source for dimension definitions, scoring thresholds, and verdict rules. This skill reads it in Step 2 to avoid duplicating definitions here.

**Relationship matrix:** This skill sits in the ralph-loop authoring chain. Co-update partners — changes to shared rubrics or phase structure must be reflected across all three:
- **ralph-prompt-create** — produces the phase prompt artefacts that this skill reviews; the 10 dimensions here must align with what ralph-prompt-create teaches authors to include.
- **ralph-prompt-auto** — auto-generates prompts using the same Q1–Q12 model; quality gaps this skill surfaces should feed back into ralph-prompt-auto's inference rules.
- **ralph-pipeline** — consumes the phase prompts this skill validates; pipeline failures often trace back to gaps in B, V, or T.

**Do not use when:**
- Reviewing skill quality — use `skill-review` instead.
- Reviewing ADRs — use `adr-review` instead.
- This skill reviews ralph-loop phase PROMPT files only (single `.md` files or pipeline directories under `prompts/`).

## Calibration references

**Gold standard — phase-11 (bug-fix phase):** `prompts/completed/phase-11-bug-fixes.md` scores ✅ on all 9 prior dimensions. **CL=❌** because it predates the concerns log requirement — do not penalise it retrospectively, but do not use it as a CL reference.

**Strong but pre-testing — phase-06:** `prompts/completed/phase-06-<datastore>-auth.md` scores ✅ on C, S, D, B, K, V, P, Z — but **T=❌** because it was written before Phase 09 established the testing requirement. Use it as a reference for B and Z quality, but do not treat it as a complete model.

**Pipeline reference — phase-21:** `prompts/completed/phase-21/` shows the correct pipeline manifest pattern: concise `produces`/`requires` YAML in `00-pipeline.md`, with full behavioural detail in step files. Evaluate pipeline phases by reading both together.

Early phases (01–05) score low on V, P, T, Z, CL — do not use them as calibration references.

**Anti-pattern: structural count as proxy for behavioural assertion.**
Verification that counts occurrences of a string in a skill or source file (e.g. `grep -c 'gh issue create'`) tests file shape, not runtime behaviour. If the string appears inside a loop, the count will always be 1 regardless of how many items are processed. When scoring V, flag any `grep -c` check on a string that:
- appears inside a `for`/`while`/`forEach` loop or iteration block in the target file, or
- is a shell command invocation whose call count scales with input size (e.g. filing one issue per bug found).

Prefer behavioural checks: run the step against a known input and assert on observable output (e.g. count of GitHub issues created, files written, lines appended).

*First identified in Phase 32 Issue #56.*
