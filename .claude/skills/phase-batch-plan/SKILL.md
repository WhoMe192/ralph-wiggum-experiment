---
name: phase-batch-plan
description: >
  Autonomous multi-phase planning: runs issue-readiness-check, groups ready issues into phases,
  creates a tracking issue, invokes ralph-prompt-auto per group, closes on completion.
  Triggers: /phase-batch-plan, batch create phases, plan all phases.
allowed-tools: Bash, Read, Glob, Agent, Skill
disable-model-invocation: true
---

# Phase Batch Plan

Autonomously plans and creates multiple ralph-loop phases from all open `ready-for-phase` issues.
No human input required. Do not use when creating a single phase from specific issues — use
`ralph-prompt-auto` instead.

## Inputs

- **Required:** none (zero-input skill — operates on all open `ready-for-phase` issues).
- **Optional:** none.
- **Missing-input behaviour:** not applicable.

---

## Success and failure criteria

**Success:** All `ready-for-phase` issues grouped into phases; tracking issue created with
checklist; each phase created by a `ralph-prompt-auto` subagent and committed; tracking issue
closed with completion summary.

**Partial success:** ≥1 phase created; ≥1 phases skipped — tracking issue closed with skipped
entries marked for human review.

**Failure (stop immediately):**
- GitHub auth fails (exit non-zero + output contains "authentication" or "401") →
  emit `Error: GitHub auth failed. Run gh auth login and retry.` and stop.
- No `ready-for-phase` issues found after Step 1 →
  emit `No ready-for-phase issues found. Add acceptance criteria to open issues and retry.` and stop.
- All groups fail phase creation → emit `All phase groups failed. See tracking issue #<N>
  for details.`, close tracking issue, and stop.

---

## Step 1 — Run issue-readiness-check

Invoke `issue-readiness-check` via the Skill tool to evaluate and label all open issues:

```
Skill tool: issue-readiness-check
```

Wait for completion. Proceed to Step 2 regardless of its output — it handles its own errors.

---

## Step 2 — Fetch ready issues

```bash
gh issue list --state open --label "ready-for-phase" \
  --json number,title,body,labels --limit 100
```

**Auth guard:** if exit code is non-zero and output contains "authentication" or "401",
emit the auth error and stop.

**Empty guard:** if result is `[]`, emit the no-issues message and stop.

Store each issue as `{ number, title, body, label_names[] }`.

---

## Step 3 — Group and prioritise issues

### 3a — Classify each issue by primary area

| Labels / body signals | Area |
|---|---|
| label `infra` | infra |
| label `harness` | harness |
| label `bug`, no `harness` | backend |
| label `enhancement` | backend |
| body contains "HTML", "Alpine", "<e2e-runner>", "form", "UI", or "page" | frontend |
| none of the above | misc |

### 3b — Extract dependencies

Scan each issue body (case-insensitive) for: `depends on #N`, `requires #N`, `blocked by #N`,
`after #N`. Store matched issue numbers as `depends_on[]` per issue.

### 3c — Build ordered groups

**Area priority:** infra → backend → frontend → harness → misc.

Within each area, topologically sort: issues with empty `depends_on` first; dependent issues
after the issues they reference. Issues with a dependency chain within an area form separate
phases in dependency order. Issues from different areas are always separate phases.

**Boundary condition:** issues in the same area with no dependency chain between them are sorted by issue number ascending.

**Merge rule:** issues in the same area with no intra-group dependencies may be merged into
one phase (max 3 issues per merged phase).

**Group label:** shared theme from issue titles; or `"<Area> improvements"` if titles share
no common noun or verb.

---

## Step 4 — Idempotency: check for an existing tracking issue

```bash
gh issue list --state open --json number,title,body --limit 50
```

Search for any issue whose `body` contains `<!-- phase-batch-plan -->`.

**If found:** read its body; identify ticked checkboxes (lines containing `- [x]`). Remove
the corresponding groups from the plan — do not re-create already-completed phases. Resume
with remaining groups, using the existing issue as `TRACKING_NUMBER`.

**If not found:** proceed to Step 5.

---

## Step 5 — Create tracking issue

Build the body from the ordered group list, then create the issue:

```bash
gh issue create \
  --title "Phase batch plan — <YYYY-MM-DD>" \
  --label "harness" \
  --body "<body>"
```

**Body template:**

```markdown
<!-- phase-batch-plan -->
Automated phase planning run — <YYYY-MM-DD>.

## Planned phases

- [ ] <Group label> (issues: #N, #M)
- [ ] <Group label> (issues: #P)

## Skipped phases

None yet.

## Status

In progress.
```

Store the returned issue URL; extract the issue number as `TRACKING_NUMBER`.

---

## Step 6 — Create each phase (sequential subagents)

For each group in order, launch one subagent:

```
Agent tool:
  subagent_type: general-purpose
  description: "Create phase for issues <numbers>"
  prompt: |
    Follow .claude/skills/ralph-prompt-auto/SKILL.md exactly.
    Issue numbers: <N> <M>
    Complete all steps including commit and push.
    Output exactly one of:
      SUCCESS <phase-dir>      e.g. SUCCESS prompts/phase-47/
      FAILURE <reason>         e.g. FAILURE issue #N body too short
```

**After each subagent returns — do not launch the next until the current one finishes:**

- **SUCCESS:** fetch current tracking issue body, replace
  `- [ ] <Group label> (issues: #N, #M)` with
  `- [x] <Group label> (issues: #N, #M) ✅ <phase-dir>`, then:
  ```bash
  gh issue edit <TRACKING_NUMBER> --body "<updated-body>"
  ```

- **FAILURE:** fetch current body, replace the unchecked line with
  `- [~] <Group label> (issues: #N, #M) ❌ SKIPPED: <reason> — needs human review`,
  append `#N, #M` to the **Skipped phases** section, then:
  ```bash
  gh issue edit <TRACKING_NUMBER> --body "<updated-body>"
  ```

Do not abort on per-phase failure — continue to the next group.

---

## Step 7 — Close tracking issue

After all groups are processed, post a completion comment and close:

**Completion comment template:**

```markdown
<!-- phase-batch-plan -->
## Run complete — <YYYY-MM-DD>

| Group | Issues | Outcome | Phase dir |
|-------|--------|---------|-----------|
| <label> | #N, #M | ✅ Created | prompts/phase-NN/ |
| <label> | #P | ❌ Skipped | reason: <error> |

**Next steps:**
- Run a phase: `/ralph-pipeline prompts/phase-NN`
- Review skipped issues: add missing information, then re-run `/phase-batch-plan`.
```

```bash
gh issue comment <TRACKING_NUMBER> --body "<completion-comment>"
gh issue close <TRACKING_NUMBER>
```

---

## Output

### Console summary (printed after Step 7)

```
Phase Batch Plan — <YYYY-MM-DD>
════════════════════════════════

  ✅ prompts/phase-NN/ — <Group label> (issues: #N, #M)
  ✅ prompts/phase-NN/ — <Group label> (issues: #P)
  ❌ SKIPPED — <Group label> (issues: #Q) — <reason>

Tracking issue: #<TRACKING_NUMBER> (closed)
Verdict: Complete
```

### Verdict rules

| Verdict | Condition |
|---------|-----------|
| **Complete** | 0 groups skipped |
| **Partial** | ≥1 group created AND ≥1 group skipped |
| **Aborted** | auth failure or no ready issues; tracking issue closed immediately if already created |

---

## Edge cases

| Situation | Action |
|-----------|--------|
| Auth failure (Step 2) | Named error message; stop immediately |
| No ready-for-phase issues (Step 2) | Named no-issues message; stop |
| Issue body empty / too short | `ralph-prompt-auto` returns FAILURE; skill records as skipped |
| All groups fail | Emit all-failed message; close tracking issue; stop |
| Dependency cycle detected | Treat both issues as independent (no `depends_on`); emit: `⚠️ Dependency cycle detected: issues #N ↔ #M treated as independent; documented in tracking issue.` |
| Existing tracking issue (Step 4) | Resume automatically — skip already-ticked groups |

---

## Standards and co-update partners

Success and failure criteria follow the workflow rubric in `docs/skill-design-standards.md`.

Skills that must be co-updated if this skill's interface changes:

| Skill | Coupling |
|-------|----------|
| `issue-readiness-check` | Called in Step 1; if label name `ready-for-phase` changes, update Step 2 filter |
| `ralph-prompt-auto` | Called in Step 6; if SKILL.md path changes, update subagent prompt path |

---

## Calibration

**Pre-requirement state:** GitHub issue #95 (`feat(skill): add phase-batch-plan skill`)
documents the design decisions that produced this skill. Verify against it if the skill's
behaviour drifts from requirements.

**Strong example:** `prompts/completed/phase-58/` — the most recent completed phase in this repo. Use its structure (pipeline manifest + numbered step files) as the reference for what a well-formed phase output looks like.

**Weak example (to avoid):** a run that invokes `ralph-prompt-auto` in the parent agent
context rather than as a subagent — causes context bleed and inflated token usage per phase.