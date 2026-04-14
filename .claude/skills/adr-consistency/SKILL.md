---
name: adr-consistency
description: >
  Scan all ADRs for contradictions, dependency violations, and temporal inconsistencies.
  Use periodically to keep the ADR set coherent. Triggers: 'adr consistency',
  'check adr conflicts', 'scan all adrs', '/adr-consistency'.
allowed-tools: Read, Glob
---

# Check for contradictions across all ADRs

**Do not use when:** analysing a single ADR (use adr-review); approving decisions (use adr-approve).

**Idempotent:** re-runs produce identical output; safe to schedule.

## Inputs

**Required:** none — operates on `docs/adr/*.md` by default.
**Optional:** none
**Missing required input:** N/A — if `docs/adr/` is empty or has fewer than 2 ADRs, report and stop (see Step 1).

## Edge cases

- **`docs/adr/` directory not found:** emit `ERROR: docs/adr/ directory not found — create it and add ADRs before running /adr-consistency` and stop.
- **Fewer than 2 ADRs:** report "Fewer than 2 ADRs found — nothing to check for consistency" and stop.
- **ADR with missing Status or Date fields:** proceed; flag the file in output as "malformed — Status or Date missing."
- **All errors:** every error path emits a named message — no silent failure.

## Step 1: Scan ADR Repository

- Glob all `*.md` files in `docs/adr/`
- **If the directory is empty or contains fewer than 2 ADRs:** report "Fewer than 2 ADRs found — nothing to check for consistency" and stop
- Read each one in numerical order
- Build an index of decisions by topic/domain
- Map relationships between ADRs (from their Related ADRs sections)

**Success criteria:** Scan is complete when all five check types (direct contradictions, implicit conflicts, scope overlaps, dependency violations, temporal inconsistencies) have been evaluated across all ADR pairs. Output must explicitly state which ADRs were checked, even if no issues are found.

## Step 2: Check for Contradictions

Read `.claude/skills/adr-consistency/adr-consistency-rules.md`

## Step 3: Related ADR Analysis

- Verify "Related ADRs" sections are bidirectionally consistent
  (if ADR 003 lists ADR 001 as related, does ADR 001 list ADR 003?)
- Identify missing relationships — ADRs that clearly relate but don't cross-reference
- Flag orphaned references to non-existent ADR numbers

## Step 4: Status Validation

Use observable, date-based criteria for all flags:

- **Superseded without replacement reference:** `**Status:** Superseded` present but no `**Superseded by:**` line present → CRITICAL
- **Deprecated without reason:** `**Status:** Deprecated` present but no `**Deprecated:**` line present → MAJOR
- **Stale Draft:** `**Status:** Draft` AND `**Date:**` is more than 30 days before today → MINOR flag ("Draft for >30 days — consider progressing to Proposed or closing")
- **Stale Proposed:** `**Status:** Proposed` AND `**Date:**` is more than 14 days before today → MINOR flag ("Proposed for >14 days — review may be stalled")

## Output

```text
ADR Consistency Report — docs/adr/ (N ADRs)
════════════════════════════════════════════

CRITICAL (direct contradictions — resolve before next phase)
  ✗ ADR 002 vs ADR 005: <description of conflict>

MAJOR (implicit conflicts or dependency issues)
  ⚠ ADR 003 depends on ADR 001's decision, but ADR 001 is now Superseded
  ⚠ ADR 004 and ADR 005 overlap on <topic> without clear precedence

MINOR (missing relationships or cleanup)
  ~ ADR 003 references ADR 001 but ADR 001 does not cross-reference ADR 003
  ~ ADR 002 has been Draft for >30 days — consider progressing or closing

No issues found in: ADR 001, ADR 002, ...

Recommendations:
  1. <specific resolution for each critical/major issue>
════════════════════════════════════════════
```

If no issues are found:

```text
All N ADRs are consistent. No contradictions, dependency violations, or orphaned references found.
```

## Standards and co-update partners

The five check types (direct contradictions, implicit conflicts, scope overlaps, dependency violations, temporal inconsistencies) and the status validation rules are shared across the ADR skill family.

| Standard | Shared with |
|----------|-------------|
| Valid status values and lifecycle order | `adr-status`, `adr-approve`, `adr-review`, `adr-check` |
| Required Related ADRs cross-reference convention | `adr-status` (Step 4 updates replacement ADR), `adr-approve` (propagation checklist) |

**Co-update trigger:** If the ADR lifecycle (valid statuses, supersession format) changes in `adr-status` or `adr-approve`, update the status validation rules in Step 4 of this skill accordingly.

## Standards and severity note

The CRITICAL/MAJOR/MINOR severity labels used in this skill's output are ADR-issue-specific severities (not the project's ✅/⚠️/❌ skill-rubric symbols). CRITICAL means "resolve before next phase"; MAJOR means "implicit conflict or dependency issue"; MINOR means "missing relationship or cleanup item". The project-standard ✅/⚠️/❌ symbols apply to the skill's own quality dimensions, not to ADR issue severity.

## Calibration

- **Strong:** `docs/adr/` (full directory, ADR-001 through ADR-007) — all ADRs consistent; no direct contradictions; bidirectional Related ADR links intact; all status validation rules pass. Should produce "All N ADRs are consistent."
- **Weak:** no committed weak corpus — a Superseded ADR without a `Superseded by:` reference is the most common real-world CRITICAL gap. Update when such a case is added.
