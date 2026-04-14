---
name: issue-refine
description: >
  Coach a GitHub issue to readiness by interactively filling R1–R5 rubric gaps. Single-issue
  complement to /issue-readiness-check. Triggers: '/issue-refine', 'refine issue',
  'fix issue gaps'.
disable-model-invocation: true
allowed-tools: AskUserQuestion, Bash, Read, Glob, Agent
---

# Issue Refine

Coaches a single GitHub issue to readiness by filling in rubric gaps interactively.
Complement to `/issue-readiness-check` — that skill identifies gaps; this skill fills them.

---

## Inputs

**Required:** `<NUMBER>` — the GitHub issue number to refine.

**Missing required input:** emit `ERROR: no issue number provided — run /issue-refine <number>` and stop.

**Invalid issue number:** if the issue is not found or not accessible, emit `ERROR: issue #<N> not found — check the issue number and your GitHub auth` and stop.

---

## Usage

```
/issue-refine <NUMBER>
/issue-refine <NUMBER> --auto
```

Processes exactly one issue. Never bulk-processes multiple issues.

**`--auto` flag:** Bypasses interactive `AskUserQuestion` prompts. Applies bot-suggested examples from the most recent `<!-- issue-readiness-check -->` comment directly, falling back to corpus defaults when no bot example is available. See Steps 4, 5, 6, and 7 for auto-mode behaviour.

---

## Edge cases

- **Issue not found:** `gh issue view <N>` exits non-zero — emit `ERROR: issue #<N> not found — check the issue number and your GitHub auth` and stop.
- **Ambiguous issue (multiple match):** if the user provides a title fragment instead of a number and multiple issues match, ask "Did you mean #<N1> (<title>) or #<N2> (<title>)?" via `AskUserQuestion` before proceeding.
- **Closed issue:** if `gh issue view <N> --json state` returns `"CLOSED"`, emit "Issue #<N> is closed — proceed anyway? (y/n)" via `AskUserQuestion`. Stop if the user answers "n".

---

## Step 1 — Resolve issue

**Flag parsing:** Before resolving the issue number, inspect the invocation args:
- If args contain `--auto`, store `auto_mode = true` and strip `--auto` from args before using the remaining token as `<NUMBER>`.
- If `--auto` is absent, store `auto_mode = false` — all existing interactive behaviour applies unchanged.

```bash
gh issue view <NUMBER> --json number,title,body,comments,labels,state
```

Store:
- `issue_number` — the issue number
- `issue_title` — the issue title
- `issue_body` — the full issue body text
- `issue_labels` — flat list of label names from the labels array
- `issue_comments` — all comment objects (each with `body`, `author`, `createdAt`)
- `issue_state` — open or closed

If the command exits non-zero, emit `ERROR: issue #<NUMBER> not found — check the issue number and your GitHub auth` and stop.

---

## Step 2 — Score rubric

Read the shared rubric file before scoring:

```
Read .claude/skills/issue-readiness-check/r1-r9-rubric.md
```

Apply R1–R5 with label modifiers — identical to `issue-readiness-check` Steps 3a–3d.

### 2a — Determine issue type modifiers

Apply the label modifiers defined in the rubric file using `issue_labels`.

### 2b — Apply Tier 1 rubric (all required)

Apply R1–R5 as defined in the rubric file. Evaluate each as **✅ Strong**, **⚠️ Partial**, or **❌ Missing**.

### 2c — Apply Tier 2 rubric (conditional)

Apply R6–R9 conditions as defined in the rubric file. Only flag if condition is true AND criterion is missing.

---

### 2d — Scan non-bot comments for rubric answers

Collect all comments that do **not** contain `<!-- issue-readiness-check -->` (i.e. human comments, not bot comments).

For each missing (❌) or partial (⚠️) criterion, check whether any human comment provides an answer of ≥20 words directly addressing that criterion:

- **R1**: Does a comment clarify what is broken or missing?
- **R2**: Does a comment describe the implementation approach or algorithm in more detail?
- **R3**: Does a comment name specific file paths or confirm a module/skill location?
- **R4**: Does a comment provide acceptance criteria, a done-when statement, or a checklist?
- **R5**: Does a comment name a test script or describe the verification approach?
- **R6–R9**: Does a comment answer the conditional Tier 2 question?

Record:
- `gaps_in_body` — criteria missing or partial in the issue body
- `gaps_answered_in_comments` — criteria with ≥20-word answers in human comments (treat as pre-confirmed)
- `gaps_unanswered` — criteria with no answer anywhere (body or comments)

---

## Step 3 — Corpus lookup

Determine issue type from labels (`harness`, `bug`, `frontend`, `backend`). If determinable,
invoke the corpus-query subagent using the Agent tool:

```
Agent tool:
  subagent_type: general-purpose
  description: "query corpus for <type> exemplars"
  prompt: |
    Follow the instructions in .claude/skills/corpus-query/SKILL.md.
    Query: return the top 2 entries where type = '<type>', ordered by review_total DESC.
    Return only the raw JSON objects, one per line, nothing else.
```

Extract `q9b_test_coverage` and `q10_verification` from the returned records. Use them to generate defaults for R4 and R5 gaps that match the pattern: `<named test file>` + `<named assertion>`.

> **Note:** Corpus results are frozen at the moment this subagent is invoked. If the corpus has been updated since invocation (e.g. new phases added via `/corpus-sync`), re-invoke `/issue-refine` to get fresh exemplars.

On failure (corpus not found, query error, or no matching records), fall back to these named defaults:
- `harness` R5 fallback: "Run the skill against a fixture issue and assert output matches expected format"
- `backend` R5 fallback: "Add a <test-runner> integration test in `<test-dir>/` that asserts the expected behaviour"
- `frontend` R5 fallback: "Add a <e2e-runner> E2E spec in `<e2e-test-dir>/` that asserts the visible change"
- Generic R5 fallback: "Add a test that exercises this change and asserts the expected behaviour"

---

## Step 4 — Produce output

Print two sections to the conversation:

```
## Issue #<N> — Refine to Readiness

**Verdict:** Ready / Needs revision / Blocked

### Recommended changes

**<Criterion name> (<R1–R5>)** ❌/⚠️
Evidence: "<exact quote from issue body — e.g. 'Acceptance criteria: none specified'>"
Fix: Add the following to the issue body:

## Acceptance Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

---

### Questions needing your input

**Q<N> — <Short label> (<R-ref>)**
<What is unclear>
> Recommended: <default answer>
> Override? [yes/no/other]
```

**Verdict field values:**
- **Ready** — all R1–R5 criteria are ✅ Strong (no changes needed)
- **Needs revision** — one or more R1–R5 criteria are ❌ Missing or ⚠️ Partial (changes recommended)
- **Blocked** — `gh issue view` exited non-zero, or the rubric file cannot be read (skill cannot proceed)

Rules:
- Only include criteria that are ❌ or ⚠️ in the recommended changes section
- Each recommended change must include an `Evidence:` quote (exact text from the issue body, or "This section is absent" if missing) and a `Fix:` block (exact text to add)
- For `gaps_answered_in_comments`: note them as "Pre-confirmed from discussion — will be merged" and do not ask about them
- For `gaps_unanswered`: list each as a question in the "Questions needing your input" section
- Use corpus-derived defaults for R4/R5 questions where available

**When `auto_mode = true`:** Print only the "Recommended changes" section listing gaps found (criterion name, ❌/⚠️ rating, brief description of the gap). Do **not** print the "Questions needing your input" section. Proceed directly to Step 5.

---

## Step 5 — Walk through questions

**When `auto_mode = false` (default interactive behaviour — unchanged):**

For each item in `gaps_unanswered`, call `AskUserQuestion` once:
- `label`: "Q<N> — <short label>"
- `description`: The recommended default — ask user to confirm ("yes"), override with specific text, or skip ("no")

Call `AskUserQuestion` **once per open question** — never batch questions.

Collect confirmed answers. Treat `gaps_answered_in_comments` items as pre-confirmed without asking.

---

**When `auto_mode = true` (replaces AskUserQuestion loop):**

For each missing (❌) or partial (⚠️) criterion in `gaps_unanswered`:

1. Fetch the issue's comments (already available in `issue_comments` from Step 1).
2. Find the most recent comment whose body contains `<!-- issue-readiness-check -->` (the bot comment).
3. In the bot comment body, extract the `> Example:` block associated with this criterion.
4. **R5 specifically:** if the extracted example names a file path, run `Glob` on that path to verify the directory exists. If the glob returns no match, try the alternative known directories (`scripts/`, `.claude/hooks/`, `<test-dir>/`) and use the first match. If no match is found, keep the bot-suggested path and append `<!-- path unverified by Glob -->` to the line.
5. If no bot comment exists on the issue, or the bot comment has no `> Example:` block for this criterion: fall back to corpus defaults (same as interactive mode — see Step 3).

After extracting all examples, treat them as pre-confirmed answers (source: "bot example" or "corpus default" — record the source for use in Step 7). Proceed to Step 6.

---

## Step 6 — Apply updates

### 6a — Idempotency check

Before writing, fetch the current issue body:

```bash
gh issue view <NUMBER> --json body
```

If the body already contains `<!-- issue-refine -->`, a previous run of this skill has already applied changes to this issue body version. In that case:

- If the rubric still shows gaps (❌/⚠️ criteria remain), proceed — the user may have re-invoked the skill intentionally to address remaining gaps.
- If all criteria are now ✅, print: "Issue #<N> was already refined and now passes all rubric criteria. No changes needed." and stop.

### 6b — Synthesise and write

Synthesise confirmed answers into a merged issue body:
- Keep all existing sections intact
- Merge confirmed answers and pre-confirmed comment answers into appropriate body sections:
  - R3 answers → add or update an **Affected files** section listing confirmed paths
  - R4 answers → add or update an **Acceptance criteria** section as a markdown checklist
  - R5 answers → add or update a **Test coverage** section naming the script and assertions
  - R2/R7 algorithm answers → expand the relevant Goal or Solution section with the detail
  - R6/R8/R9 answers → add the relevant section if missing
- Do not quote comment text verbatim — rewrite into clean structured prose/lists that read as if the author wrote them
- Do not add sections for criteria not mentioned in answers
- If user answered "no" (skip) to a question, do not apply that criterion's suggested text
- Append `<!-- issue-refine -->` as the last line of the body (invisible in GitHub UI; used for idempotency detection on re-runs)

**Auto-applied markers:** When `auto_mode = true`, append `<!-- auto-applied -->` as an HTML comment immediately after each auto-applied section heading (e.g. `## Acceptance Criteria <!-- auto-applied -->`). Criteria that were skipped (no example available, user answered "no") do **not** receive the marker.

```bash
gh issue edit <NUMBER> --body "<merged-body>"
```

If `gh issue edit` exits non-zero, report the full error and the intended body text so the user can apply it manually.

---

## Step 7 — Confirm

Print:

```
### Run complete

**Status:** Success

**Actions taken:**
- Merged answers for R<N>, R<N> into issue body
- Wrote updated body via `gh issue edit <NUMBER>`

**Output:** Issue #<N> updated. Run `/issue-readiness-check` to label it if it now passes all criteria.
```

**When `auto_mode = true`:** the **Actions taken** list must enumerate:
- Which criteria were auto-applied, with source indicated in parentheses: "bot example" or "corpus default" (e.g. "R4 Acceptance Criteria — auto-applied (bot example)")
- Which criteria were skipped, with reason: "no bot example available" (e.g. "R3 Affected Files — skipped (no bot example available)")

---

## Success and failure criteria

**Success** — all of the following are true:
- `gh issue view` returned a valid issue body (Step 1 completed without error)
- At least one rubric criterion was ❌ or ⚠️ (there was something to refine)
- The user confirmed or skipped every question in `gaps_unanswered` (Step 5 completed)
- `gh issue edit` exited zero and the issue body now contains the merged answers (Step 6 completed)

**Partial success** — acceptable outcomes that do not constitute failure:
- All criteria were already ✅ (nothing to refine) — print "Issue #<N> already meets all rubric criteria. No changes needed." and stop after Step 2
- User answered "no" (skip) to every question — print "No changes applied. Issue body unchanged." and stop after Step 5

**Failure** — any of the following:
- `gh issue view` exits non-zero or returns an empty body — emit `ERROR: issue #<N> not found — check the issue number and your GitHub auth` and stop
- `gh issue edit` exits non-zero — report the full error and the intended body text so the user can apply it manually (do not retry silently)
- The rubric file `.claude/skills/issue-readiness-check/r1-r9-rubric.md` cannot be read — stop and ask the user to verify the file exists

---

## Standards and co-update partners

Primary criteria source: `.claude/skills/issue-readiness-check/r1-r9-rubric.md` (R1–R5 and R6–R9 definitions and label modifiers)

Co-update partners: `issue-readiness-check` — shares R1–R9 rubric; update together when any criterion changes.

---

## Calibration examples

| Quality | Issue | Why |
|---------|-------|-----|
| ✅ Strong (pre-refine) | GitHub issue #92 ("chore: upgrade @anthropic-ai/sdk to eliminate residual DEP0040 punycode warning") | Passed readiness check with no gaps; demonstrates what a fully-refined issue looks like — use as target state. Verified via GitHub at time of writing (2026-04-12). |
| ❌ Weak (needs refining) | GitHub issue #85 ("bug: cards placed in archived <external-service> columns are invisible to board users") | Typical gaps in R3 and R5 that `/issue-refine` is designed to fill. Verified via GitHub at time of writing (2026-04-12). |

---

## Constraints

- Never add `ready-for-phase` label — left exclusively to `/issue-readiness-check`
- Never bulk-process multiple issues — exactly one issue number per invocation
- Never update phase prompts — `/ralph-prompt-review`'s role
- Rubric (R1–R5, label modifiers, Tier 2 conditions) must be identical to `issue-readiness-check/SKILL.md`
- If user answers "no" (skip) to a question, do not apply that criterion's suggested text
- Call `AskUserQuestion` once per open question — never batch questions
- No test file — harness-only skill (pure markdown). Verification is observational.
