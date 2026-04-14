## Step 5 — Offer corrections

**Idempotency guard:** Before writing any entry, check whether `phase-runs.yaml` already contains a record with the same `phase_id`. If a record exists, skip the write and report "already present — skipped" in the findings table. Do not write a duplicate entry even if the user confirms.

For each `BACKFILL` candidate that does not already have a `phase-runs.yaml` record, use `AskUserQuestion` to confirm before writing a synthetic entry to `phase-runs.yaml`:

```yaml
  - phase_id: "<id>"
    run_id: "<id>-001"
    completed_at: "<completed date from phases.yaml>T00:00:00Z"
    outcome: success
    attribution: backfilled
    concern_score: 0
    concerns_file: null
    total_cost_usd: null
    notes: "Backfilled by /phase-sync — original run predated phase-runs.yaml"
```

For each `REVIEW` candidate, use `AskUserQuestion` to ask whether to:
- Mark as `completed` in phases.yaml (if the user confirms the work is done)
- Backfill a run record and mark completed simultaneously
- Leave as-is

When marking as `completed`, show the exact YAML change before writing:

```yaml
# Before:
- id: "22"
  status: in-progress

# After:
- id: "22"
  status: completed
  completed_at: "YYYY-MM-DDT00:00:00Z"
```

**Quality rules:**
- Never write to `phases.yaml` or `phase-runs.yaml` without explicit user confirmation per entry
- Never mark a phase as `completed` without user confirmation
- The `--apply` flag (if provided as an argument) should be noted in output but does not bypass the confirmation requirement — each write still requires explicit confirmation

**Success criteria:** Sync is complete when the findings table is printed and all BACKFILL/REVIEW candidates have been actioned (confirmed, skipped, or left as-is by the user). ✅ if registry is consistent at end; ⚠️ if user skipped items; ❌ if any write failed.