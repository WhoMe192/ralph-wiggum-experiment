---
name: adr-check
description: >
  Pre-submission completeness checklist for an ADR. Mechanical section/field presence —
  faster than adr-review. Do not use for content quality (use adr-review).
  Triggers: 'check adr', 'adr checklist', '/adr-check'.
argument-hint: "<adr-number or filename>"
allowed-tools: Read, Glob
---

# Pre-submission completeness check for an ADR

**Target**: $ARGUMENTS

## Inputs

**Required:** ADR number (e.g. `006`) or filename (e.g. `docs/adr/006-title.md`)
**Optional:** none
**Missing required input:** If `$ARGUMENTS` is empty, emit `ERROR: no ADR specified — provide an ADR number or filename` and stop.

## Idempotency

Re-running on the same ADR with no edits in between produces identical output. This skill is read-only — it never modifies files.

## Step 1: Locate the ADR

- If a number is provided (e.g. `006`), find `docs/adr/006-*.md`
- If a filename is provided, use it directly
- If no matching file is found, stop: "No ADR found matching '$ARGUMENTS'. Check the number or filename and try again."
- If the ADR file cannot be read or parsed, emit: `ERROR: Cannot read [filename] — [reason]. Stopping.`

## Step 2: Run Checklist

Read `.claude/skills/adr-check/adr-check-rules.md`

## Output template

```text
ADR Check — ADR NNN: Title
════════════════════════════

FAIL
  ✗ Decision section does not start with "We will..."
    Evidence: "We chose to use Cloud Run for its scalability..."
    Fix: Change the opening sentence to start with "We will use Cloud Run..."

  ✗ Only 1 alternative considered (need at least 2)
    Evidence: "## Alternatives Considered\n#### Option A: Lambda"
    Fix: Add a second alternative with both pros and cons listed.

PASS
  ✓ File naming and title format correct
  ✓ Status and date fields present
  ✓ Background is substantive (≥150 characters)
  ...

Verdict: NOT READY — fix 2 issues before review
════════════════════════════
```

If all checks pass:

```text
ADR Check — ADR NNN: Title
════════════════════════════
All checks passed.
Verdict: READY FOR REVIEW
════════════════════════════
```

Offer to run `/adr-review` for a deeper content and style review.

## Standards and co-update partners

The required section names (`## Background`, `## Alternatives Considered`, `## Decision`, `## Consequences`, `## Related ADRs`, `## References`) and valid status values (`Draft`, `Proposed`, `Accepted`, `Superseded`, `Deprecated`) are shared across the ADR skill family.

| Standard | Shared with |
| --- | --- |
| Required section names and minimum section count | `adr-review`, `adr-new` |
| "We will..." decision prefix | `adr-review`, `adr-new` |

**Co-update trigger:** If the ADR section list or status enum changes, update all skills listed above together.
