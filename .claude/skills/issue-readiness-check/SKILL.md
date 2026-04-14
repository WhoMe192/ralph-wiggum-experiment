---
name: issue-readiness-check
description: >
  Review open GitHub issues against the ralph readiness rubric. Posts gap comments, adds or
  removes the ready-for-phase label. Triggers: 'issue readiness', 'check issues',
  'readiness check', '/issue-readiness-check'.
allowed-tools: Bash, Read, Glob
---

# Issue Readiness Check

Evaluates every open GitHub issue against the Tier 1–2 readiness rubric derived from the
`ralph-prompt-create` question sequence. An issue is **ready** when a phase prompt could be
auto-generated from it without producing `[VERIFY]` markers or requiring human clarification.

**Do not use when you want to refine or improve an issue's content — use `/issue-refine` instead. This skill only checks readiness status against the rubric.**

---

## Inputs

**Required:** GitHub issue number(s) or "all open" — the issues to check for readiness.

**Optional:** `--label <name>` (default: checks all open issues) — filter by label.

**Missing required input:** If no issue number or scope is provided, ask: "Which issue(s) would you like to check? Provide a number, comma-separated list, or 'all'."

---

## Step 1 — Ensure the `ready-for-phase` label exists

```bash
gh label create "ready-for-phase" \
  --color "0e8a16" \
  --description "Issue has all information needed to create a ralph phase prompt" \
  --force
```

`--force` is a no-op if the label already exists.

---

## Step 2 — Fetch all open issues

```bash
gh issue list --state open --json number,title,body,labels,updatedAt --limit 100
```

**Auth failure guard:** If the command exits non-zero with an auth error (output contains "authentication" or "401"), emit: "Error: GitHub auth failed. Run `gh auth login` and retry." and stop.

**Empty list guard:** If the command returns an empty array (`[]`), emit: "No open issues found. Nothing to check." and stop.

Store the full list. Process each issue in turn — do not skip any.

---

## Step 3 — For each issue: evaluate the rubric

**Empty/malformed body guard:** If `body` is null, empty, or fewer than 20 characters, assign ❌ to R1, R2, R4, and R5 immediately without further evaluation. Flag the issue in the run summary with "(body missing)". Continue to Step 5 to post a needs-info comment.

Read the shared rubric file before scoring (R1–R9 criteria defined in `.claude/skills/issue-readiness-check/r1-r9-rubric.md`):

```
Read .claude/skills/issue-readiness-check/r1-r9-rubric.md
```

This file is shared with `issue-refine`. When criteria change, both skills must be updated together.

### 3a — Determine issue type modifiers

Apply the label modifiers defined in the rubric file.

### 3b — Apply Tier 1 rubric (all required)

Apply R1–R5 as defined in the rubric file. Evaluate each as **✅ Strong**, **⚠️ Partial**, or **❌ Missing**.

### 3c — Apply Tier 2 rubric (conditional — only flag if the issue type warrants it)

Apply R6–R9 conditions as defined in the rubric file. Only include in comment if condition is true AND criterion is missing.

---

### 3d — Scan non-bot comments for rubric answers

After scoring the rubric, collect all comments that do **not** contain `<!-- issue-readiness-check -->` (i.e. human comments, not bot comments).

For each missing (❌) or partial (⚠️) criterion, check whether any human comment provides a substantive answer:

- **R1**: Does a comment clarify what is broken or missing?
- **R2**: Does a comment describe the implementation approach or algorithm in more detail?
- **R3**: Does a comment name specific file paths or confirm a module/skill location?
- **R4**: Does a comment provide acceptance criteria, a done-when statement, or a checklist?
- **R5**: Does a comment name a test script or describe the verification approach?
- **R6–R9**: Does a comment answer the conditional Tier 2 question?

Record:
- `gaps_answered_in_comments` = list of criteria (e.g. `[R3, R4, R5]`) that have substantive answers in human comments
- `gaps_unanswered` = list of criteria that still have no answer anywhere

If `gaps_answered_in_comments` is non-empty, proceed to **Step 6a** (body synthesis) instead of posting a needs-info comment.

---

## Step 4 — Determine readiness verdict

An issue is **ready** when:
- All applicable Tier 1 criteria (R1–R5, adjusted for modifiers) score ✅ or ⚠️ Strong/Partial with the partial being minor
- No criterion scores ❌

An issue is **not ready** when any Tier 1 criterion scores ❌, or more than one scores ⚠️.

Apply the following binary rules — no judgment calls:
- **Ready**: zero ❌ findings AND at most one ⚠️ across all applicable criteria
- **Not ready**: one or more ❌ findings, OR two or more ⚠️ findings

A single ⚠️ does not block readiness. Two or more ⚠️ always means not ready, regardless of which criteria they are on.

---

## Step 5 — Check existing state

For each issue, fetch the existing comments and current labels:

```bash
gh issue view <NUMBER> --json comments,labels,updatedAt
```

Check for an existing readiness comment by looking for the marker `<!-- issue-readiness-check -->`
in any comment body.

Compute:
- `has_bot_comment` = true if any comment contains `<!-- issue-readiness-check -->`
- `bot_comment_created_at` = createdAt of the most recent matching comment
- `body_updated_after_comment` = issue `updatedAt` > `bot_comment_created_at`
- `has_ready_label` = true if `ready-for-phase` is in the issue's current labels
- `has_confirmation_request` = true if any comment contains `<!-- issue-readiness-check-awaiting-confirmation -->`
- `confirmation_request_at` = createdAt of the most recent `awaiting-confirmation` comment
- `confirmed` = true if any non-bot comment was posted after `confirmation_request_at`

---

## Step 6 — Act

Apply the following decision table:

| Verdict | Has label | Awaiting confirmation | Confirmed | Comments answer gaps | Action |
|---|---|---|---|---|---|
| Ready | No | — | — | — | Add label + post ready comment |
| Ready | Yes | — | — | — | No action (already correct) |
| Not ready | — | Yes | No | — | No action (awaiting author reply) |
| Not ready | — | Yes | Yes | — | Re-evaluate body; apply normal verdict |
| Not ready | Yes | No | — | Yes | Remove label + synthesise body update (Step 6a) |
| Not ready | Yes | No | — | No | Remove label + post needs-info comment |
| Not ready | No | No | — | Yes | Synthesise body update (Step 6a) |
| Not ready | No | No | — | No | Post needs-info comment (if not already posted for this body version) |

### Adding the label

```bash
gh issue edit <NUMBER> --add-label "ready-for-phase"
```

### Removing the label

```bash
gh issue edit <NUMBER> --remove-label "ready-for-phase"
```

### Step 6a — Synthesise body update and request confirmation

When `gaps_answered_in_comments` is non-empty, do the following instead of posting a needs-info comment.

**1. Draft the merged body**

Produce a new version of the issue body that:
- Keeps all existing sections intact
- Merges the answers from human comments into the appropriate sections:
  - R3 answers → add or update an **Affected files** section listing confirmed paths
  - R4 answers → add or update an **Acceptance criteria** section as a markdown checklist
  - R5 answers → add or update a **Test coverage** section naming the script and assertions
  - R2/R7 algorithm answers → expand the relevant Goal or Solution section with the detail
  - R6/R8/R9 answers → add the relevant section if missing
- Does **not** include comment text verbatim — synthesise into clean, structured prose/lists
- Does **not** add sections for criteria that were not mentioned in comments

**2. Apply the update with overwrite guard**

Before editing the issue body, fetch the current body content and compare it to the merged draft. Only proceed with the update if the readiness-related sections have changed:

```bash
gh issue view <NUMBER> --json body --jq '.body'
```

If the existing body already contains the synthesised content (markers and sections match), skip the edit and proceed directly to checking confirmation state. Only run the following if the merged body differs from the current body:

```bash
gh issue edit <NUMBER> --body "<merged-body>"
```

**3. Post a confirmation-request comment**

Post a comment using the `<!-- issue-readiness-check-awaiting-confirmation -->` marker:

```markdown
<!-- issue-readiness-check-awaiting-confirmation -->
📝 I've updated this issue body to incorporate the answers from the discussion thread.

**Please review the updated body and reply to this comment to confirm the changes are accurate.** Once confirmed, the next readiness check will evaluate the updated body and add the `ready-for-phase` label if all criteria pass.

If anything is incorrect, reply with the correction and I'll revise.
```

Do **not** add the `ready-for-phase` label at this point.

**4. On the next check run — detect confirmation**

When Step 5 runs for this issue on a subsequent check:

- `has_confirmation_request` = true if any comment contains `<!-- issue-readiness-check-awaiting-confirmation -->`
- `confirmation_request_at` = createdAt of the most recent matching comment
- `confirmed` = true if any non-bot comment was posted **after** `confirmation_request_at`

If `confirmed` is true: proceed with normal rubric evaluation (Steps 3a–3d) against the current body and apply the standard readiness verdict (label and ready/needs-info comment).

If `confirmed` is false and `has_confirmation_request` is true and the body has not been updated since the confirmation request: no action (avoid spam — still awaiting reply).

If `gaps_unanswered` is non-empty after the confirmed re-evaluation, post a targeted needs-info comment covering only those remaining gaps.

---

### Posting a needs-info comment

Compose a comment that includes:
1. The hidden marker (first line, not visible in GitHub UI): `<!-- issue-readiness-check -->`
2. A brief intro line
3. Only the criteria that are missing or partial — not the full rubric
4. Specific fill-in prompts, not generic questions
5. A closing line confirming the check will re-run automatically

**Comment template (needs-info):**

```markdown
<!-- issue-readiness-check -->
Hi 👋 This issue was checked against the ralph phase-readiness rubric. Before it can be turned into an implementation phase, a few details are needed.

**Please add the following to the issue body:**

[INSERT: one block per missing/partial criterion — see format below]

Once these are added, the next check will mark this `ready-for-phase` automatically.
```

**Per-criterion block format:**

```markdown
**Missing: <criterion name> (R<N>)**
> <Specific fill-in prompt tailored to this issue>
> Example: <short illustrative example matching the issue's domain>

**Evidence:** "<exact quote from the issue body showing the gap, or 'This section is absent.' if no relevant text exists>"

**Fix:** Add a `## <Section Heading>` section with <exact content required — e.g. ≥3 bullet points describing the expected behaviour after the change is applied>.
```

Tailor the example to the issue's domain — do not use generic placeholder text.

**Harness R5 wording (when `harness` label present):**

```markdown
**Missing: Test coverage (R5 — harness)**
> Which shell test script will verify this works? What command does it run, and what output does it assert?
> Example: `scripts/test-issue-readiness.sh` runs the skill against a fixture issue and asserts the correct label was applied.

**Evidence:** "No mention of a shell test script or verification command in the issue body."

**Fix:** Add a `## Test coverage` section naming the shell script path (e.g. `scripts/test-<feature>.sh`) and the specific output assertions it will check (e.g. "asserts exit code 0 and that label `ready-for-phase` was applied to issue #N").
```

### Posting a ready comment

```markdown
<!-- issue-readiness-check -->
✅ This issue passes the ralph phase-readiness rubric — all required information is present. The `ready-for-phase` label has been added.

To generate a phase prompt: `/ralph-prompt-auto <NUMBER>`
```

---

## Step 7 — Print a run summary

After processing all issues, print a summary table to the conversation:

```
Issue Readiness Check — <date>
══════════════════════════════

  #42  ✅ Ready            — label added
  #50  ✅ Ready            — already labelled, no action
  #11  ❌ Not ready        — missing R3, R4, R5 — comment posted
  #12  ❌ Not ready        — missing R5 — comment posted
  #13  ❌ Not ready        — missing R2, R3, R4, R5 — comment posted

5 issues checked. 2 ready. 3 need info.
```

---

## Calibration examples

| Quality | Issue | Why |
|---------|-------|-----|
| ✅ Strong | #85 ("bug: cards placed in archived <external-service> columns are invisible to board users") | Has `ready-for-phase` label; R1–R5 all present with specific file paths and named test assertions |
| ✅ Strong (harness) | #81 ("bug(harness): Step 3c-uat silently skips when no UAT build found") | Has `ready-for-phase` + `harness` label; R5 correctly uses shell script verification pattern |
| ❌ Weak | #91 ("bug: saving board config clears active label description for orange_dark colour") | No `ready-for-phase` label; missing R3 file paths and R5 test coverage |

See `docs/skill-calibration-manifest.md` for the canonical per-skill reference paths.

---

## Quality rules

- Never post the same comment twice on an issue that has not been updated since the last check
- Never add `ready-for-phase` to a closed issue
- Never post a needs-info comment on an issue that is already labelled `ready-for-phase` without first verifying the re-evaluation verdict
- Tailor every fill-in prompt to the specific issue — do not use generic boilerplate
- Keep comments concise — only list what is actually missing, not the full rubric
- Never add `ready-for-phase` while an issue is in the "awaiting confirmation" state
- When synthesising a body update, do not quote comments verbatim — rewrite into clean structured prose/lists that read as if the author wrote them
- If the author's confirmation reply includes a correction, apply the correction via another `gh issue edit` before re-evaluating
