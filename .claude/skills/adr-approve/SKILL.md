---
name: adr-approve
description: >
  Mark an ADR as Accepted and propagate the decision to relevant project documentation.
  Use when an ADR has been reviewed and is ready to be officially accepted. Triggers:
  'approve adr', 'accept adr', 'mark adr accepted', '/adr-approve'.
argument-hint: "<adr-number or filename>"
disable-model-invocation: true
allowed-tools: Read, Edit, Write, Glob
---

# Mark an ADR as Accepted and propagate to project documentation

**Target**: $ARGUMENTS

**Do not use when:** the ADR is still under review — run `/adr-review` first. This skill is for final acceptance, not draft iteration.

## Inputs

**Required:** ADR number (e.g. `006`) or filename (e.g. `docs/adr/006-title.md`)
**Optional:** none
**Missing required input:** If `$ARGUMENTS` is empty, emit `ERROR: no ADR specified — provide an ADR number or filename` and stop.

## Step 1: Locate and Read the ADR

- If a number is provided (e.g. `006`), find `docs/adr/006-*.md`
- **If no matching file is found:** emit "Error: No ADR found matching '[identifier]'. Run `ls docs/adr/` to list available ADRs." and stop.
- **If multiple files match:** list all matches and ask "Which ADR did you mean?" — do not proceed until the user selects one.
- Read the full file
- Verify the current status is `Draft` or `Proposed` — if already `Accepted`, confirm with
  the user before proceeding

## Step 2: Update the ADR Status

Edit the ADR file:

- Change `**Status:** Draft` (or `Proposed`) to `**Status:** Accepted`
- **Idempotency guard:** Only update `**Date:**` if the current status is NOT already `Accepted`. If re-approving a previously accepted ADR (user confirmed in Step 1), preserve the existing date unless the user explicitly asks to update it.

**Concrete edit example** — the exact text change made in the ADR file:

```diff
-**Status:** Proposed
+**Status:** Accepted
```

Status: Proposed → Accepted

Save the file.

## Step 3: Propagate the Decision

After updating the status, check each of the following files using this binary checklist. For each applicable file, show the exact content to add or change, then ask `Update [file] with this change? (yes / skip)`. Only apply changes the user confirms.

**Always check (run through this checklist for every approval):**

| File | Check condition | Action if applicable |
|------|-----------------|----------------------|
| `docs/architecture.md` | ADR decision changes system design, tech choices, integration patterns, or deployment topology | Add a paragraph cross-referencing the ADR number and decision |
| `CLAUDE.md` | ADR establishes a constraint for AI-assisted development (mandatory tool, forbidden approach, required pattern) | Add or update the relevant section, quoting the ADR number |

**Check when applicable:**

| File | Check condition | Action if applicable |
|------|-----------------|----------------------|
| `docs/deployment.md` | ADR changes deployment process or infra config | Add a note referencing the ADR |
| `docs/testing-strategy.md` | ADR mandates a testing approach or tool | Add a note referencing the ADR |
| `docs/adr/README.md` | File exists | Add the new ADR to the index |

For any file that does not exist, skip it silently.

For each applicable file, show the author exactly what content should be added or changed, then ask:

```text
Update [filename] with this change? (yes / skip)
```

Only apply changes that the user confirms.

## Step 4: README Quality Check (optional)

If any README file was among the files updated in Step 3, offer:

```text
README.md was updated. Run /readme-check on it now? (yes / no)
```

## Propagation Principles

- Extract actionable constraints and decisions — do not copy the ADR wholesale
- Be specific: "Use Cloud Run for all service deployments" not "Cloud Run was chosen"
- Cross-reference the source ADR number so decisions are traceable
- Keep documentation files focused — add only what changes behaviour or understanding

## Output format

After all steps complete, emit a summary block:

```text
ADR Approval — ADR NNN: Title
══════════════════════════════
Status: Draft → Accepted
Date:   YYYY-MM-DD

Propagation:
  ✅ docs/architecture.md — updated (paragraph added)
  ✅ CLAUDE.md — updated (constraint added)
  ⚠️  docs/deployment.md — skipped by user
  —  docs/testing-strategy.md — not applicable

ADR NNN is now Accepted.
```

## Success criteria

This skill succeeds when:
1. The ADR file's `**Status:**` field reads `Accepted` and `**Date:**` is updated to today
2. Every applicable downstream doc has been offered for update and the user has confirmed or skipped each
3. No downstream file was modified without explicit user confirmation

This skill fails if the ADR file is not found, is already `Accepted` and the user declines to re-approve, or if a file write error occurs.

## Standards

Shared standard: ADR lifecycle rules. Co-update partners: adr-status, adr-refine, adr-review, adr-check.

**ADR structure rules** — shared with `adr-review`, `adr-refine`, `adr-check`, `adr-consistency`.

- The status field values (`Draft`, `Proposed`, `Accepted`) and the `**Status:**` / `**Date:**` markdown syntax follow the ADR structure convention defined in `docs/adr/` and enforced by `adr-check`.
- The set of downstream propagation targets (`docs/architecture.md`, `CLAUDE.md`, `docs/deployment.md`, `docs/testing-strategy.md`) was derived from a survey of which project docs are kept in sync with architectural decisions — this is the same corpus used by `adr-review` when checking traceability.

**Co-update trigger:** If the ADR section structure changes (e.g. `**Status:**` is renamed, new mandatory sections are added, or the `docs/adr/README.md` index format changes), all skills in the ADR family must be updated together: `adr-approve`, `adr-review`, `adr-refine`, `adr-check`, `adr-consistency`.

**Source:** `docs/skill-design-standards.md` — Relationship map (shared standards), ADR structure rules row.

## Calibration

- **Strong:** `docs/adr/005-cicd-quality-gates-and-security-tooling.md` — clear decision + status trail; `docs/architecture.md` and `CLAUDE.md` both updated with specific cross-references. Should produce a complete Propagation block with all applicable files confirmed.
- **Weak:** `docs/adr/001-automation-platform-and-orchestration-architecture.md` — predates current propagation conventions; running approval here would surface the most downstream docs to update.
