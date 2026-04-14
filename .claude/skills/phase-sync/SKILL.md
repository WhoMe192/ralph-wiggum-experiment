---
name: phase-sync
description: >
  Detects and corrects discrepancies between prompts/phases.yaml and prompts/phase-runs.yaml,
  cross-checked against git history and deliverable file existence. Produces a findings table
  and offers to backfill missing run records or correct stale status fields, with user
  confirmation before writing.
  Triggers: 'phase-sync', 'sync phases', 'phase registry', '/phase-sync'.
argument-hint: "[--apply]"
---

The phase registry (`prompts/phases.yaml`) tracks every ralph phase with a `status` field and — for completed phases — execution fields (concern_score, steps_total, completed_at, etc.). The runs log (`prompts/phase-runs.yaml`) is an active-run scratchpad that is cleared to `runs: []` on successful completion. Historical execution data lives in `phases.yaml`, not `phase-runs.yaml`. This skill surfaces status inconsistencies and offers guided corrections with user confirmation before any write.

Invoke `/phase-sync` whenever the registry feels out of date, after manually completing a phase outside the pipeline, or to audit the overall phase state.

**Do not use when:** you only need to query phase status without writing — use `/corpus-query` instead. This skill is for registry correction, not read-only reporting.

## Inputs

**Required:** none — operates on `prompts/phases.yaml` and `prompts/phase-runs.yaml` by default.
**Optional:** `--apply` flag — noted in output, but does not bypass per-write confirmation.
**Missing required input:** N/A — runs on default registry files; if either file is absent, see Edge cases below.

## Output template

**Success output:**
```
### Run complete

**Status:** Success

**Actions taken:**
- prompts/phase-runs.yaml — backfilled run record for phase-22 (status: in-progress → completed)
- prompts/phases.yaml — updated status: in-progress → completed for phase-22

**Verdict:** ✅ Registry consistent at end of run
```

**Partial output** (user skipped items):
```
### Run complete

**Status:** Partial

**Completed:** phase-22 backfilled
**Skipped:** phase-15 — user chose to leave as-is

**Verdict:** ⚠️ Registry partially corrected — 1 item left for next run
```

**Already-done output:**
```
### Run complete

**Status:** Already done

**No changes made.** Registry is consistent — nothing to do.
Re-run is safe — no side effects occurred.
```

## Edge cases

- **`prompts/phases.yaml` not found:** emit `ERROR: phases.yaml not found at prompts/phases.yaml — run /phase-sync after generating a phases.yaml file` and stop.
- **`prompts/phase-runs.yaml` not found:** proceed without it; treat `run_ids` set as empty.
- **Malformed YAML:** emit `ERROR: <filename> contains invalid YAML — fix the syntax before running /phase-sync` and stop.
- **Invalid status enum:** emit `ERROR: Phase <id> has unknown status '<value>'. Valid values: available, in-progress, failed, completed` and stop.
- **Ambiguous phase ID:** if multiple phases share the same partial ID pattern, ask "Did you mean phase-<X> or phase-<Y>?" via AskUserQuestion.
- **Partial artefact (missing fields):** proceed with available fields; note which fields were missing in the findings table.
- **All errors:** every error path emits a named message — no silent failure.

<!-- TODO: Add this skill to the relationship map in docs/skill-design-standards.md under a "phases.yaml schema" row alongside corpus-sync, once parallel-edit risk is resolved. -->

---

## Step 1 — Read registry files

Read both source files to understand current state:

```bash
cat prompts/phases.yaml
cat prompts/phase-runs.yaml 2>/dev/null || echo "(no phase-runs.yaml yet)"
```

**Malformed YAML guard:** If either file fails to parse (invalid YAML syntax), emit:
"Error: [filename] contains invalid YAML. Fix the syntax before running /phase-sync."
and stop. Do not proceed with partial data.

**Invalid enum guard:** If any `status` field in `phases.yaml` contains a value not in `[available, in-progress, failed, completed]`, emit:
"Error: Phase [id] has unknown status '[value]'. Valid values: available, in-progress, failed, completed."
List all invalid entries, then stop.

Parse each phase entry from `phases.yaml` (fields: `id`, `status`, `completed`).
Parse each run entry from `phase-runs.yaml` (fields: `phase_id`, `run_id`, `completed_at`, `outcome`).

Build two sets:
- `yaml_ids` — all phase IDs from phases.yaml
- `run_ids` — all `phase_id` values from phase-runs.yaml

---

## Step 2 — Identify candidates

A phase is a **candidate** if any of the following is true:

- Its `status` in phases.yaml is not `completed` (i.e. `available`, `in-progress`, or `failed`)

A phase is `OK` if its `status` is `completed` in phases.yaml — skip it. Presence or absence in `phase-runs.yaml` is irrelevant: completed phases have their execution fields in `phases.yaml`; `phase-runs.yaml` is a scratchpad for active runs only.

---

## Step 3 — Cross-check each candidate

For each candidate phase ID (zero-padded, e.g. `22`), gather evidence:

```bash
# Git evidence — count matching commits
git log --oneline | grep -i "phase-22\|phase-22 " | wc -l

# Deliverable spot-check — list prompt directory if it exists
ls prompts/completed/phase-22/ 2>/dev/null | head -5
```

Assign a verdict based on the evidence. "Git evidence exists" means `wc -l` output is ≥ 1:

| Condition | Verdict |
|-----------|---------|
| phases.yaml = `completed` | `OK` (omit from findings table) |
| phases.yaml ≠ `completed` AND commit count ≥ 1 | `REVIEW` |
| phases.yaml ≠ `completed` AND commit count = 0 | `CANDIDATE` |

---

## Step 4 — Print findings table

Output a findings table covering all non-OK candidates:

```
Phase  phases.yaml    phase-runs.yaml  Git evidence       Verdict
-----  -----------    ---------------  ---------------    -------
15     completed      missing          yes (3 commits)    BACKFILL
22     in-progress    missing          yes (1 commit)     REVIEW
31     completed      present          yes                OK
```

If no candidates are found, output:

```
Registry is consistent — nothing to do.
```

---

## Step 5 — Offer corrections

Read `.claude/skills/phase-sync/phase-sync-rules.md`

## Calibration

- **Strong:** `prompts/phases.yaml` — registry file used as direct input; validate that phase-58 is present with `status: completed` and `completed_at` set.
- **Weak:** no committed artefact yet — no stale-status phase exists in the repo as a reference for a REVIEW/BACKFILL run. Update when a phase is found in the `in-progress` or `failed` state after confirmed completion.

---

## Standards

- **Verdict thresholds** — derived from the `phases.yaml` schema (`status` enum: `available`, `in-progress`, `failed`, `completed`) and the ralph-pipeline convention that `phase-runs.yaml` is a scratchpad cleared after each successful run. No external specification.
- **Scoring conventions** — verdict labels (OK / REVIEW / CANDIDATE / BACKFILL) and success/failure symbols (✅ / ⚠️ / ❌) follow `docs/skill-design-standards.md`.
- **Co-update dependencies** — `corpus-sync` also reads `prompts/phases.yaml`; if the `phases.yaml` schema changes (field names, status enum values), both skills must be updated together.
