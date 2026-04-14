---
name: ralph-pipeline
description: >
  Orchestrate a phase pipeline of ralph-loop steps with dependency analysis, test-gating,
  and failure retry. Triggers: 'ralph pipeline', 'run pipeline', '/ralph-pipeline'.
argument-hint: "<phase-directory-path, e.g. prompts/phase-10-description/>"
disable-model-invocation: true
allowed-tools: AskUserQuestion, Bash, Read, Edit, Write, Glob, Agent, Skill
---

# Ralph Pipeline

Orchestrate a phase pipeline from a directory of single-deliverable step files, where each step runs as its own ralph-loop.

## Inputs

| Input | Format | Required | Notes |
|-------|--------|----------|-------|
| Phase directory path | `prompts/phase-NN/` | No | If omitted, reads `prompts/phases.yaml` to select next available phase |
| Shorthand `next` or `latest` | Keyword | No | Selects lowest `status: available` phase from `prompts/phases.yaml` |
| No argument | — | — | If 1 available phase, auto-selects; if 2+, presents a pick list via `AskUserQuestion` |

**Pre-conditions:** `00-pipeline.md` must exist in the phase directory. If absent, stop and report "No `00-pipeline.md` found — run `/ralph-prompt-create` or `/ralph-preflight` first."

## When to invoke

User says: "run the pipeline for phase-09", "start ralph-pipeline on prompts/phase-09",
"run next", "run latest", or provides a path to a phase directory containing `00-pipeline.md`.

## Step -1 — Resolve phase directory

**If a phase directory path was provided:** use it directly. Skip to Step 0.

**If the argument is `next` or `latest`:** read `prompts/phases.yaml`, filter to `status: available`, sort by `id` ascending, take the first entry. Use its `directory` field.

**If no argument was provided:** read `prompts/phases.yaml`, filter to `status: available`, sort by `id` ascending:
- **0 available:** tell the user and stop.
- **1 available:** auto-select. Announce: "Only one available phase — running Phase `<id>`: `<name>`."
- **2+ available:** present via `AskUserQuestion` — label = "Phase `<id>` — `<name>`", description = `<summary>`. Ask: "Which phase do you want to run?"

## Harness bug log

When the pipeline encounters a problem with its **own infrastructure** (not a phase step failure),
append an entry to `<phase-dir>/harness-bugs.md` **before continuing**.

Harness bugs include: dependency token mismatches requiring a patch, skill invocations that failed, shell commands that failed due to CWD drift, or pipeline machinery requiring manual intervention.

Entry format:
```markdown
## Bug — <short title> — <step where detected>

**Where:** Step <N> — <description>
**What happened:** <what the pipeline tried, what failed, what workaround was used>
**Root cause:** <skill file or template that needs fixing>
**Suggested fix:** <the specific change>
```

Do **not** stop execution to file the bug — log it and proceed. It is reviewed and filed at Step 3e.

---

## Step -1b — Check for interrupted run

Read `prompts/phase-runs.yaml`. Find the latest entry for the current `phase_id`
where `outcome: in-progress`.

**If NOT found:** proceed normally to Step 0.

**If found:** present via `AskUserQuestion`:

> **Interrupted run detected** — Phase `<phase_id>` run `<run_id>` started at `<started_at>`.
>
> Steps completed: `<steps_completed>`. Steps remaining: `<steps_remaining>`.
>
> **A. Resume** — skip completed steps, continue from `<next_step>`
>    *(or go straight to Step 3 if all steps are already done)*
> **B. Restart from scratch** — mark old run `abandoned`, begin a new run

Wait for the user's choice.

**Choice A — Resume:**
- Restore `START_SHA` from the run record's `start_sha` field
- Restore `RUN_ID` from the run record's `run_id` field
- Compute `steps_remaining = steps_total − steps_completed`
- **If `steps_remaining` is empty** (all steps done, only Step 3 was missed):
  Skip Steps 0–2 entirely and proceed directly to Step 3 (pipeline complete sequence).
- **If `steps_remaining` is non-empty:**
  Begin Step 1 at the first step in `steps_remaining`, skipping already-completed steps.
  Skip Step 0b-ii (run record already written for this run_id).

**Choice B — Restart:**
- Update the existing in-progress record: set `outcome: abandoned`
- Proceed normally to Step 0 (which will write a new run record at Step 0b).

## Step 0 — Parse and analyse dependencies

0b. **Record the start SHA:**
```bash
START_SHA=$(git rev-parse HEAD)
```

### 0b-ii. Write initial run record

Extract step ids from the phase pipeline:

```bash
node scripts/pipeline-deps.js <phase-dir>/00-pipeline.md 2>/dev/null \
  | uv run python -c "import sys,json; d=json.load(sys.stdin); print([s['id'] for s in d.get('steps',[])])" \
  2>/dev/null || echo "[]"
```

Store the result as `STEPS_TOTAL`.

**Determine run_id:** read `prompts/phase-runs.yaml`, find all entries for this `phase_id`,
and use the next sequential 3-digit zero-padded number (e.g. if `38-001` exists, use `38-002`).
If no prior entries exist, use `<phase>-001`. Store as `RUN_ID`.

**Check for pre-existing in-progress record:**
If any existing entry for this `phase_id` has `outcome: in-progress`, update it to
`outcome: abandoned` before appending the new record.

**Initialise `prompts/phase-runs.yaml`** (only if the file is entirely absent — do NOT reinitialise or overwrite if the file exists):
- If absent: create it with `runs: []` header, then proceed.
- If present: leave the file contents intact. Only append the new run entry below.

**Append (never overwrite)** to `prompts/phase-runs.yaml`:

```yaml
  - phase_id: "<phase>"
    run_id: "<RUN_ID>"
    started_at: "<now ISO-8601>"
    completed_at: null
    outcome: in-progress
    start_sha: "<START_SHA>"
    steps_total: <STEPS_TOTAL>
    steps_completed: []
    concern_score: null
    concerns_file: null
    total_cost_usd: null
    notes: null
```

Do **not** commit `prompts/phase-runs.yaml` here — it is committed only at Step 3h.

1. Read `<phase-dir>/00-pipeline.md`
2. Run dependency analysis:
   ```bash
   node scripts/pipeline-deps.js <phase-dir>/00-pipeline.md
   ```
3. If exit code non-zero, stop and show the error.
4. Capture `output.phase` as `<phase>` and `max_iterations_per_step` (default `5`) from the JSON/pipeline.
5. If step order differs from sorted order, inform the user.
6. For each "requires token not produced" warning:
   - **Naming mismatch** (produces token is a superset of the requires token): show the pair, offer to patch `00-pipeline.md` with the exact requires token, apply on confirmation, re-run `pipeline-deps.js`. Append a harness bug entry describing the mismatch.
   - **Genuinely missing**: pause and ask the user to resolve before continuing.

**Per-step `per_step` override (optional):** Each step in `00-pipeline.md` may declare a `per_step` key to override the global `tests.per_step` for that step only. If the key is absent or null, the global value is used. This allows steps to reference test files that are only created by earlier steps.

Example:
```yaml
steps:
  - id: "01-slug"
    # no per_step key — uses global tests.per_step
    produces: [...]
  - id: "02-slug"
    per_step: "bash -n scripts/test-new-file.sh"   # overrides global for this step
    produces: [...]
```

## Step 0d — Pre-execution read and summarise (mandatory)

Before executing any step, read every step file in resolved execution order and output a delivery summary:

```
Phase <phase>: <description>
<N> step(s) to execute: <step-ids in order>

Deliverables:
  [<step-id>]
  • <file-path> — <action> — <one-line description>

Tests: <per_step> per step; <full_suite> at the end
```

Then proceed immediately to Step 1.

## Step 1 — Execute each step in order

### 1a. Run the ralph-loop for this step

Spawn a subagent using the `Agent` tool:
- `subagent_type`: `general-purpose`
- `description`: `ralph-loop step <step-id>`
- `prompt`:

```
You are running one step of a ralph-loop pipeline. Your job is to implement
the deliverable described in the step file, then emit DONE when complete.

Invoke the ralph-loop skill for this step:
  skill: ralph-loop:ralph-loop
  args: "Read @<phase-dir>/<step-id>.md for the requirements" --max-iterations <max_iterations_per_step> --completion-promise "DONE"

Working directory: /workspaces/ralph-wiggum-experiment
Do NOT commit `prompts/phases.yaml` or `prompts/phase-runs.yaml`. These are
registry files committed exclusively by the pipeline orchestrator in Step 3h.
Stage only the deliverable files for this step.
Before emitting DONE, run `git status` and stage and commit all deliverable files listed in
this step's Deliverables section. Do not emit DONE if any listed deliverable file appears
as modified or untracked in `git status` output.
```

Using `Agent` (not `Skill`) is critical — it runs the ralph-loop inside a subprocess so the stop hook is fully contained there.

### 1a-err. Handle ralph-loop execution errors

**The subagent errored** if any of these are true: output does not contain `DONE`, output contains `max iterations reached`, `FAILED`, `Error:`, `fatal`, or the subagent threw an exception.

If an error is detected:

1. Summarise:
   > **ralph-loop error in step `<step-id>`**
   > **What happened:** `<1–2 sentence summary>`
   > **Last agent output (truncated):** `<last ~20 lines>`
   > **Likely causes:** hit max iterations / ambiguous step prompt / missing dependency / stop hook fired unexpectedly

2. Present options:
   - **A. Increase `max_iterations_per_step`** in `00-pipeline.md` and re-run.
   - **B. Rewrite the step prompt** — add context, clarify deliverable, specify paths/commands.
   - **C. Skip this step** — mark skipped and continue.
   - **D. Abort pipeline** — set `status: failed` in `prompts/phases.yaml` and stop.

3. Wait for choice. Apply it.

Do **not** proceed to step 1b if a ralph-loop execution error was detected.

### 1a-post. Post-DONE validation

**1. Verify deliverable files are committed:**
```bash
git status --porcelain
```
If any file that should have been committed appears as modified or untracked, log a harness bug and re-run the commit before proceeding.
When re-running the commit, exclude `prompts/phases.yaml` and `prompts/phase-runs.yaml`
— these are committed only by the orchestrator in Step 3h.

**2. Check concerns.md for new entries from this step:**
```bash
grep -A5 "^## <step-id>" <phase-dir>/concerns.md 2>/dev/null | head -20
```
If the heading exists and contains anything other than "no concerns", flag it to the user and present A/B/C options (rewrite / skip / abort). Wait for choice.

### 1b. Run per-step tests

Determine the test command for this step:
1. If the current step's YAML block in `00-pipeline.md` contains a `per_step` key with a non-null, non-empty value, use that value as the test command.
2. Otherwise, use `tests.per_step` from the pipeline global config.
3. If the resolved command is null, empty string, or the key is absent — skip this step: log "per_step: none for step <step-id> — skipping" and continue to Step 1c.

Run the resolved command.

A test has **failed** if: command exits non-zero, **or** output contains error text (`Error:`, `SyntaxError:`, `FAILED`, stack traces, etc.). Do not proceed on failure.

If failure is due to a missing tool/package: fix environment, re-run once. If still failing, treat as test failure.

### 1c. Handle result

**Tests pass:** stage and commit only the deliverable files for this step — do not use
`git add .` or `git add -A`. Use explicit file paths matching the step's declared
deliverables. Always use absolute paths and prefix with `cd /workspaces/ralph-wiggum-experiment &&`
to guard against CWD drift (subagents may have a different working directory):

```bash
cd /workspaces/ralph-wiggum-experiment && git add <absolute-file-path> [<absolute-file-path> ...] && git commit -m "feat: phase-<phase> step <step-id> complete"
```

Commit message: `feat: phase-<phase> step <step-id> complete`.

**Update steps_completed:** find the entry in `prompts/phase-runs.yaml` with
`run_id = <RUN_ID>` and append the current step id to its `steps_completed` list.

Do **not** commit this change — `prompts/phase-runs.yaml` is committed only at Step 3h.

Move to next step.

**Tests fail, retries remaining:**
1. Append `## Failure Context (attempt <N>)` with full test output to the step `.md`.
2. Decrement retries and re-run from 1a.

**Tests fail, retries exhausted:** Pause and present:
- **A. Rewrite the step prompt** — clarify requirements.
- **B. Skip this step** — mark skipped, continue.
- **C. Abort pipeline** — stop and review manually.

**Step appears under-specified** (repeatedly fails with ambiguity signals):
> "Step `<step-id>` appears under-specified. Please update `<phase-dir>/<step-id>.md` with the missing context, then I'll re-run this step."

## Step 2 — Full suite test

Read `.claude/skills/ralph-pipeline/ralph-pipeline-rules.md`

## Step 3 — Pipeline complete

Read `.claude/skills/ralph-pipeline/ralph-pipeline-complete/SKILL.md` and follow the
instructions there exactly.

## Standards and co-update partners

This skill implements the Ralph-Wiggum iterative AI development methodology. Each step runs as a single ralph-loop iteration — this boundary is intentional: it limits context accumulation and ensures each deliverable is independently verifiable before the next begins.

| Standard | Shared with |
|----------|-------------|
| Phase registry schema (`prompts/phases.yaml` fields: `id`, `status`, `directory`) | `phase-sync` — audits registry consistency; `ralph-preflight` — reads registry before preflight |
| Run record schema (`prompts/phase-runs.yaml`) | `phase-sync` — backfills missing run records; `corpus-sync` — checks `concern_score` before adding to corpus |
| Per-step test gate (exit code check + output error signal check) | `ralph-guardrails` — identical test failure rules enforced in every ralph-loop iteration |
| `full_suite` must be `<project-defined full-suite command>` | `ralph-prompt-create` — embeds this value in generated `00-pipeline.md`; `ralph-guardrails` — enforces the rule during loops |

**Co-update trigger:** If `00-pipeline.md` schema changes (new fields, renamed keys), update the `pipeline-deps.js` parser AND the field references in Steps 0, 1a, and 2 of this skill.

## Calibration

- **Strong:** `prompts/completed/phase-58/` — most recent completed phase; all steps executed in dependency order, per-step tests passed, full suite green, run record written to `prompts/phase-runs.yaml` with `outcome: success`. Should produce a clean pipeline-complete sequence.
- **Weak:** `prompts/completed/phase-09/` — early single-step pipeline format; predates current dependency-ordering conventions and `00-pipeline.md` schema. Use to verify step-id resolution and backward compatibility paths.
