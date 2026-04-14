---
name: ralph-parallel-subagents
description: >
  Parallelise independent ralph-phase workstreams using sub-agents when deliverables share
  zero output files. Triggers: 'parallelise phase', 'run sub-agents in parallel',
  'fan out workstreams', '/ralph-parallel-subagents'.
argument-hint: "<path to PROMPT file, e.g. prompts/phase-10-description/PROMPT.md>"
disable-model-invocation: true
allowed-tools: Agent, Bash, Read, Glob, Grep
---

# Ralph Parallel Sub-agents

Pattern for fanning out independent workstreams within a ralph-loop iteration using parallel sub-agents.

## Inputs

| Input | Type | Required | Default / fallback |
|-------|------|----------|--------------------|
| PROMPT file path | arg (positional) | Optional | Infer from context: look for an open `prompts/phase-*/PROMPT.md` referenced in the current conversation or the most recently modified phase directory |
| Workstream override | inline instruction | Optional | Use the default ownership table below |

**Missing-input behaviour:**
- If no PROMPT path is provided and none can be inferred from context, ask the user: "Which PROMPT file should I parallelise? (e.g. `prompts/phase-10-description/PROMPT.md`)"
- If the PROMPT file is provided but does not exist, report: "PROMPT file not found at `<path>`. Check the path and retry." Do not proceed.
- If a PROMPT file is found but contains only one deliverable, report that parallelisation is not applicable and run the single deliverable sequentially.

## When to use this pattern

Apply parallel sub-agents only when ALL of the following binary criteria are met:

1. The prompt contains two or more deliverables that share **zero output files** — if `git diff --name-only` after each workstream would show entirely disjoint file sets, they are independent.
2. Each workstream's file set maps exclusively to one entry in the Workstream ownership table below — no file appears in more than one workstream's "Owns" column.
3. Each workstream has at least one runnable gate check that can be executed without reading any other workstream's output (e.g. `tofu validate` needs only `infra/`; `bash -n` needs only `application/`).

Do not parallelise if deliverables share files like `CLAUDE.md`, `infra/main.tf`, or `workflow/` — sequential execution is safer in those cases.

## Workstream ownership — default split for this repo

| Workstream | Owns | Must not touch |
|------------|------|----------------|
| `infra` | `infra/` | `application/`, `workflow/`, `docs/` |
| `application` | `application/` | `infra/`, `workflow/`, `docs/` |
| `docs` | `docs/`, `CLAUDE.md` (append only) | `infra/`, `application/`, `workflow/` |
| `devcontainer` | `.devcontainer/` | everything else |

If a new workstream doesn't fit this table, define its ownership explicitly before spawning.

## How to execute

### Step 1 — Decompose

Read the PROMPT file and list each deliverable. Group into independent workstreams using the ownership table above. If any deliverable spans two workstreams, assign it to one and note the dependency.

### Step 2 — Spawn sub-agents in parallel

Use the Agent tool to spawn one sub-agent per workstream in a **single message** (parallel tool calls). For each sub-agent, provide:

- The specific deliverables it owns
- The directories it may read and write
- The directories it must not touch
- The gate check to run on completion (e.g. `tofu validate`, `bash -n`)

Example prompt structure for each sub-agent:
```
You are working on the [workstream] workstream.
Deliverables: [list]
May read/write: [directories]
Must not touch: [directories]
On completion, run [gate check] and report pass/fail.
```

### Step 0 — Idempotency check

Before spawning sub-agents, check if any phases are already complete:

```bash
git log --oneline | grep -i "phase-" | head -5
```

If commits show that workstream deliverables are already merged, skip those workstreams and report "already completed" in the status table. Do not re-run work that is already committed.

**Running this skill twice is safe and idempotent.** Step 0 detects already-completed workstreams before re-spawning any sub-agent. On a second run against the same set of steps, no duplicate sub-agent launches occur for workstreams whose deliverables are already committed — those workstreams are reported as "already completed" and skipped.

### Step 3 — Collect and validate results

Wait for all sub-agents to complete. For each:

1. Check the gate check result (pass/fail)
2. **If a sub-agent failed its gate:** re-invoke it using the Agent tool with the same prompt it was given originally. Do not re-run passing workstreams. If it fails a second time, escalate to the user with the full gate-check error output and stop — do not commit.
3. Check for cross-cutting conflicts: run `git diff --name-only` and look for files modified by more than one workstream

### Step 4 — Merge and commit

Once all gates pass and no conflicts exist:

1. Review the combined diff with `git diff`
2. Confirm no placeholder values remain (`grep -r "REPLACE_ME\|YOUR_" --include="*.tf" --include="*.sh" --include="*.md"`)
3. Commit all changes in a single commit with a message summarising all workstreams completed

## Success criteria / Failure conditions

**This skill succeeds when ALL of the following are true:**

1. Every workstream's gate check reports pass
2. `git diff --name-only` shows no file modified by more than one workstream
3. No placeholder values remain (`REPLACE_ME`, `YOUR_`) in any changed file
4. A single commit is created summarising all completed workstreams
5. The status table (see Output format) is emitted before the commit step

**This skill fails (and must stop, not commit) when ANY of the following are true:**

| Failure condition | Required action |
|-------------------|----------------|
| A workstream gate check fails | Retry that workstream alone; do not commit until it passes |
| Two workstreams modified the same file | Escalate to user; do not attempt auto-merge |
| PROMPT file not found | Report error and stop |
| Only one deliverable found | Report that parallelisation is not applicable; offer to run sequentially |
| A sub-agent reports it cannot complete its deliverables | Stop, report the blocker, do not commit partial results |

## Escalation

If two workstreams produce conflicting changes to the same file, do not attempt an automatic merge. Report the conflict clearly to the user and wait for instruction before committing.

## Output format

After Step 3, report status in this structure before proceeding to Step 4:

**Success output:**
```
### Run complete

**Verdict:** Success

Parallel execution complete — <N> workstreams

| Workstream    | Gate check         | Result  | Files changed |
|---------------|--------------------|---------|---------------|
| infra         | tofu validate      | ✅ Pass | 3             |
| application  | bash -n            | ✅ Pass | 5             |
| docs          | (none)             | ✅ Pass | 2             |

Cross-cutting conflicts: None
Combined diff: <N> files changed

Ready to commit? [yes / no — if no, state which workstream to retry]
```

**Partial output** (some workstreams passed, at least one failed):
```
### Run complete

**Verdict:** Partial

| Workstream    | Gate check         | Result  | Files changed |
|---------------|--------------------|---------|---------------|
| infra         | tofu validate      | ✅ Pass | 3             |
| application  | bash -n            | ❌ Fail | 0             |

**Blocked workstream:** application
**Reason:** <exact gate-check error output>
**Next step:** Fix the error above and re-invoke this skill for the application workstream only.
```

**Failed output** (all workstreams failed):
```
### Run complete

**Verdict:** Failed

All <N> workstreams failed their gate checks. No commit was made.
**Next step:** Review each gate-check error above and resolve before re-running.
```

**Already-done output** (idempotency — all workstreams already committed):
```
### Run complete

**Verdict:** Already done

All workstreams already committed. No sub-agents were launched.
Re-run is safe — no side effects occurred.
```

**Blocked output** (cross-cutting conflict or missing PROMPT — user action required):
```
### Run blocked

**Verdict:** Blocked

**Reason:** <exact conflict description or missing precondition>
**Next step:** <concrete action the user should take>
```

**Verdict selection rules:**

| Verdict | Trigger condition |
|---------|-------------------|
| `Success` | All workstreams' gate checks pass and no cross-cutting conflicts exist |
| `Partial` | ≥1 workstream passed and ≥1 workstream failed its gate check |
| `Failed` | All workstreams failed their gate checks |
| `Already done` | Step 0 finds all workstream deliverables already committed; no sub-agents launched |
| `Blocked` | A cross-cutting conflict exists (two workstreams modified the same file), or PROMPT file not found — user action required before proceeding |

## Standards

| Standard | Source / rationale | Co-update partners |
|----------|-------------------|--------------------|
| Workstream ownership table (infra / application / docs / devcontainer) | Derived from the repo's directory structure as documented in `CLAUDE.md` (Repository Structure section) and validated against completed phases in `prompts/phase-corpus.yaml`. Update this table whenever a new top-level directory is added to the repo. | `ralph-guardrails` (references same repo structure); `ralph-pipeline` (uses same workstream decomposition logic) |
| Parallelisation pre-conditions (independence, exclusive file ownership) | Based on the ralph-loop iterative development methodology — sequential execution is the safe default; parallelism is opt-in only when ownership is provably exclusive. Rationale in `docs/workflow.md`. | `ralph-guardrails`, `ralph-pipeline` |
| Placeholder detection pattern (`REPLACE_ME`, `YOUR_`) | Project convention established in ralph-loop phases; enforced by `ralph-guardrails`. | `ralph-guardrails` |

<!-- TODO(CO): Verify that ralph-parallel-subagents is listed in the relationship map in
     docs/skill-design-standards.md under the workstream ownership standard shared with
     ralph-guardrails and ralph-pipeline. Do NOT edit that file directly — raise as a
     maintenance task when the relationship map is next updated. -->

## Calibration examples

| Quality | Reference | Why |
|---------|-----------|-----|
| ✅ Strong | `prompts/completed/phase-09/` — infra + application deliverables are fully independent (separate directories, separate gate checks) | Textbook ownership split: `infra/` vs `application/` with no shared files |
| ❌ Weak | `prompts/completed/phase-09/00-pipeline.md` — phase-09 predates the current parallelisation conventions; its pipeline steps were not split by workstream ownership, and some steps touched shared files (`CLAUDE.md`), which would cause merge conflicts under this skill's rules. No committed failed parallel execution case yet — update when first failed parallel execution case is documented. |
