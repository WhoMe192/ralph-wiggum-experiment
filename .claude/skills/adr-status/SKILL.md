---
name: adr-status
description: >
  Update the status of an existing ADR to Superseded, Deprecated, or Proposed. For Accepted
  use /adr-approve. Use when an ADR's lifecycle state needs updating. Triggers: 'update adr
  status', 'supersede adr', 'deprecate adr', '/adr-status'.
argument-hint: "<adr-number> <new-status>"
disable-model-invocation: true
allowed-tools: Read, Edit, Glob
---

# Update the status of an existing ADR

**Arguments**: $ARGUMENTS
**Expected format**: `<adr-number> <new-status>`
**Example**: `006 Superseded`

## Standards

### Shared standard: ADR lifecycle rules

This skill enforces the canonical ADR status lifecycle defined across all ADR skills in this project:

```
Draft → Proposed → Accepted → Superseded | Deprecated
```

**Rationale for each status value:**

| Status | Rationale |
| --- | --- |
| `Draft` | Author is still writing; not yet ready for review |
| `Proposed` | Author has submitted for team review; no decision yet |
| `Accepted` | Team has approved; enforced by `/adr-approve` which also propagates the decision to project docs |
| `Superseded` | A newer ADR replaces this one; the replacement ADR must back-reference this one |
| `Deprecated` | The approach is no longer recommended but no single ADR replaces it (e.g. tooling abandoned) |

**Source:** ADR structure rules are the shared standard across this skill family. If the valid status values or lifecycle transitions change, all of the following skills must be co-updated:

- `adr-review` — validates status field during quality review
- `adr-refine` — may suggest status changes during coaching
- `adr-check` — pre-submission checklist checks status field is present and valid
- `adr-consistency` — detects invalid or out-of-order status transitions across the corpus
- `adr-approve` — transitions an ADR to `Accepted` and is the only skill authorised to do so

> This skill handles all status transitions **except** `Accepted`. Use `/adr-approve` for that transition.

---

## Valid Statuses

| Status | Meaning |
| --- | --- |
| `Draft` | Work in progress, not yet proposed |
| `Proposed` | Submitted for review |
| `Accepted` | Approved and active — use `/adr-approve` instead |
| `Superseded` | Replaced by another ADR |
| `Deprecated` | No longer recommended but not formally replaced |

> Note: To mark an ADR as `Accepted`, use `/adr-approve` — it also propagates the decision to project docs.

## Step 1: Parse Arguments

- Extract ADR number (e.g. `006`)
- Extract new status
- **Validate status:** If the requested status is not one of `Draft`, `Proposed`, `Superseded`, `Deprecated`, emit: "Error: '[value]' is not a valid status. Valid values: Draft, Proposed, Superseded, Deprecated. (Use /adr-approve for Accepted.)" and stop.
- If arguments are missing or ambiguous, ask the user to confirm

## Step 2: Locate and Read the ADR

- Find `docs/adr/006-*.md`
- Read the current status and date
- If the `Status:` field is absent or malformed, emit: `ERROR: No valid Status field found in [filename].`

## Step 2b: Idempotency guard

Read the current `**Status:**` field. If it already matches the requested new status, stop:
"ADR NNN is already `<status>`. No changes made." Do not update the date or re-add sections.

## Step 3: Update the ADR

**For Superseded**:

1. Change `**Status:**` to `Superseded`
2. Update `**Date:**` to current date
3. Add a section after the date fields:

```markdown
**Superseded by:** [ADR NNN: Title](NNN-title.md) — <one-line reason>
```

4. Update the Related ADRs section to reference the replacement ADR

**For Deprecated**:

1. Change `**Status:**` to `Deprecated`
2. Update `**Date:**` to current date
3. Add a section after the date fields:

```markdown
**Deprecated:** <YYYY-MM-DD> — <explanation of ≤2 sentences stating the reason for deprecation, e.g. "tooling no longer maintained; team has migrated to X">
```

**For Proposed**:

1. Change `**Status:**` to `Proposed`
2. Update `**Date:**` to current date

## Step 4: Update Related ADRs (if Superseded)

If marking as Superseded:

- Read the replacement ADR
- Add a Related ADRs entry in the replacement: "Supersedes [ADR NNN](NNN-title.md)"
- Confirm with the user before editing the replacement ADR

## Step 5: Confirm

Show a summary in this format:

```text
ADR Status Update — ADR NNN: Title
════════════════════════════════════
Status: [old] → [new]
Date:   YYYY-MM-DD

Files changed:
  ✅ docs/adr/NNN-*.md — status and date updated
  ✅ docs/adr/MMM-*.md — Related ADRs updated (Superseded case only)

ADR NNN is now [new status].
```

If user declined the Related ADR update: replace ✅ with ⏭  and note "skipped by user".

**Verdict enum** — the final line of every run must be one of:
- `Status updated: [old] → [new]`
- `No change required`
- `Error: status already [X]`

Offer to commit with `/smart-commit`.

## Success criteria

This skill succeeds when:
1. The ADR's `**Status:**` field matches the requested new status
2. The `**Date:**` field is updated to today's date
3. For Superseded: the `**Superseded by:**` line is present and the replacement ADR's Related ADRs section is updated (with user confirmation)

This skill fails if the ADR file is not found, the requested status is invalid, or the status already matches (idempotency stop in Step 2b).

## Calibration

- **Strong:** `docs/adr/007-multi-environment-strategy-dev-uat-prod.md` — most recently created ADR with a clear status trail; updating its status demonstrates the full lifecycle change with idempotency guard.
- **Weak:** `docs/adr/001-automation-platform-and-orchestration-architecture.md` — predates current status conventions; running a status update here exercises the "already Accepted" guard path.
