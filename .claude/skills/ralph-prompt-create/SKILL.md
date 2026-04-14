---
name: ralph-prompt-create
description: Creates complete ralph-loop PROMPT files through a structured question-by-question conversation, then writes the finished file to prompts/phase-NN-description.md. Use when drafting a new ralph phase, expanding a partial prompt draft, or starting a new ralph-loop iteration for this project.
argument-hint: "[--create | partial-prompt-file | issue-number]"
allowed-tools: AskUserQuestion, ToolSearch, Bash, Read, Write, Glob, Grep, Skill
---

# Ralph Prompt Create

Guides creation of a complete ralph-loop PROMPT file through a structured question-by-question conversation, then writes the final file using patterns from PROMPT3.md (the reference quality standard in this repo).

## --create mode (bootstrap prereqs)

If `--create` is the first argument, initialise the ralph-loop phase registry and supporting
directories, then **stop** — do not proceed to the Q&A sequence. This mode is idempotent.

### Create 1 — prompts/ directory

```bash
mkdir -p prompts/completed
```

Report: `created prompts/ and prompts/completed/` or `directories already exist — skipped`.

### Create 2 — phases.yaml

```bash
test -f prompts/phases.yaml && echo "EXISTS" || echo "MISSING"
```

If `MISSING`, write `prompts/phases.yaml`:

```yaml
phases: []
```

Report: `created prompts/phases.yaml` or `already exists — skipped`.

### Create 3 — phase-runs.yaml

```bash
test -f prompts/phase-runs.yaml && echo "EXISTS" || echo "MISSING"
```

If `MISSING`, write `prompts/phase-runs.yaml`:

```yaml
runs: []
```

Report: `created prompts/phase-runs.yaml` or `already exists — skipped`.

### Create 4 — pipeline-deps.js availability check

```bash
test -f scripts/pipeline-deps.js && echo "OK" || echo "MISSING"
```

If `MISSING`, report:
`⚠️ WARNING: scripts/pipeline-deps.js not found. This is required by /ralph-pipeline to
 analyse step dependencies. Restore it from git history before running /ralph-pipeline.`

### Create 5 — Summary

Output a table:

```
ralph-prompt-create bootstrap complete.

  prompts/phases.yaml      <created | already existed>
  prompts/phase-runs.yaml  <created | already existed>
  prompts/completed/       <created | already existed>
  scripts/pipeline-deps.js <✅ found | ⚠️ missing — see above>
```

Then output the next step:

```
Bootstrap complete — run /ralph-prompt-create <goal> to create your first phase.
```

**Stop here. Do not begin the Q&A sequence.**

---

## Success and failure criteria

**Success:** All of the following are true:
- `prompts/phase-NN-<slug>.md` exists and contains all 7 sections (Context, What to build, Deliverable specs, Constraints, Self-verification, Loop execution strategy, Signal completion)
- `prompts/phase-NN/00-pipeline.md` exists with valid `phase`, `steps`, and `tests.full_suite` fields
- One step file per `id` declared in `00-pipeline.md` exists at `prompts/phase-NN/<id>.md`
- `prompts/phases.yaml` contains a new entry for this phase with `status: available`
- `ralph-prompt-review` quality review completed and verdict is either "Ready to run" or user accepted gaps

**Failure:** Stop and report clearly if:
- All questions are answered but the user declines to proceed at the plan-confirmation step
- `gh issue list` fails with an auth error in Q4a — report the error and instruct the user to re-authenticate before continuing
- The Write tool is blocked because a file already exists and the user chose not to overwrite (see idempotency guard in Final output)

**Prompt quality is not independently assessed by this skill.** Gap detection is delegated to `/ralph-prompt-review` (Step 6). Do not invent a separate quality check — invoke that skill as specified.

---

## How to invoke

The user may provide:
- `--create` — bootstrap the `prompts/` directory structure and stop (see `--create mode` above)
- A goal description inline (e.g. "add a web frontend for the orchestrator")
- A partial draft to expand — read it first, then identify gaps and ask about them
- No argument — begin the question sequence immediately

**Do not write the prompt until all questions have been answered.** Ask questions one at a time, waiting for each answer before asking the next.

Use the `AskUserQuestion` tool for every question — it presents a focused input dialog rather than a chat message, which makes answering faster and reduces back-and-forth. Fetch it first if not yet available: `ToolSearch select:AskUserQuestion`.

**Handling partial or ambiguous answers:** If a user answer contains fewer than 1 named deliverable (for Q4), no file path (for Q4 file questions), or no clear yes/no (for yes/no questions), re-ask with a clarifying prompt: "I didn't quite catch that — could you clarify [specific aspect]?" Retry up to 2 times before marking the answer as `[VERIFY]` and continuing. Answers marked `[VERIFY]` must be flagged in the plan summary table with `Low` confidence and called out explicitly before the user confirms.

---

## Question sequence

Read `question-sequence.md` in this skill directory for the complete Q1–Q12 question sequence. Work through every question in order without skipping any.

---

## After all questions are answered

Before writing, summarise the full plan back to the user and ask for confirmation using `AskUserQuestion`:

```
Here is the plan for PROMPT<N>.md:

Phase goal: <one sentence>
Deliverables (<N> files): <list with Create/Update/Delete>
Iteration groups: <numbered list>
Key constraints: <bullet list>
Verification: <one sentence per deliverable type>
Architecture diagrams: <"docs/architecture.md updated — <what changes>" or "no changes needed — <reason>">

Shall I write this now?
```

Only proceed when the user confirms.

### Concrete plan summary example

A completed Q&A session for a backend phase (e.g. "add label role editor") produces a plan summary like this:

| Q | Inferred answer | Confidence |
|---|-----------------|------------|
| Q1 | Add a label role editor API and UI for the German BU board | High |
| Q2 | Phase 40 deployed orchestrator with <datastore> board configs | High |
| Q3 | Do not modify `infra/main.tf` or `<source-dir>/<external-service>.js` | High |
| Q4 | Create `<source-dir>/labelRoles.js`, Update `<source-dir>/index.js` | High |
| Q4a | Maps to issue #77 (resolved) | High |
| Q4b | `labelRoles.js: getLabelRoles`, `index.js: POST /admin/label-roles` | Medium |
| Q4c | No UI deliverables — skip | High |
| Q5 | POST `/admin/label-roles` → `{labels: [{id, role}]}` | High |
| Q6 | Validate label IDs against <external-board>, persist to <datastore> | High |
| Q7 | `<EXT_API_KEY>`, `<EXT_TOKEN>` from Secret Manager | High |
| Q8 | Node.js 20, npm, no bare python3 | High |
| Q9 | Auth cookie required; never log token values | High |
| Q9b | Add `test/labelRoles.test.js` with <test-runner>; 3 test cases | High |
| Q10 | `node --check` + `npm test` + `curl /health` | High |
| Q11 | 2 groups: (1) labelRoles.js + index.js, (2) test file | High |
| Q12 | Add Phase 41 runbook to `docs/deployment.md` | High |

Items marked `Medium` confidence were inferred — user confirmed or corrected before writing.

---

## PROMPT file structure

Read `prompt-template.md` in this skill directory for the exact section structure and templates. Write sections in the order shown there. Every section is required.

---

## Standards

- **Tooling rules** in generated prompts must follow `docs/tech-stack.md`: `uv run python` not `python3`, `tofu` not `terraform`, `<project-defined full-suite command>` for `full_suite`
- **Scope list** for Conventional Commits scopes must stay in sync with CLAUDE.md and `smart-commit/SKILL.md` — update all three if a new top-level directory is added
- **Documentation placement**: runbooks → `docs/deployment.md`; repo-working conventions → `CLAUDE.md`. Do not mix these
- **12-question framework** — Q1–Q12 defined in `question-sequence.md` in this skill directory and grounded in the Ralph-Wiggum methodology as documented in `docs/skill-design-standards.md` (see §Research basis: G-EVAL and analytic rubrics).

### Skill relationship map

| Related skill | Relationship |
|---------------|-------------|
| `ralph-prompt-review` | Downstream consumer — reviews every prompt this skill produces (Step 6). Uses the same Q1–Q12 quality dimensions as its scoring framework. |
| `ralph-prompt-auto` | Sibling — uses the same Q1–Q12 sequence for automated (non-interactive) prompt generation. If the question set changes, update both skills. |
| `ralph-pipeline` | Downstream executor — consumes `00-pipeline.md` and step files written by this skill. Field names (`steps`, `produces`, `requires`, `tests.full_suite`) must stay compatible. |

**Co-update trigger:** If the Q1–Q12 question sequence changes, or the `00-pipeline.md` schema changes, update `ralph-prompt-create`, `ralph-prompt-auto`, `ralph-prompt-review`, and `ralph-pipeline` together.

## Quality calibration

Before writing the prompt, load [examples.md](examples.md) for bad vs good comparisons grounded in this repo's actual phase prompts.

The reference standard (strong example) is **`prompts/completed/phase-58/`** — a multi-step pipeline with dependency ordering, issue tracking, and full self-verification (see `docs/skill-calibration-manifest.md`). For simpler single-deliverable phases, `prompts/completed/phase-03-<workflow-provider>-orchestrator.md` remains a useful reference for section structure and API schema detail.

The weak example is **`prompts/completed/phase-09/`** — an early pipeline that predates the current `produces`/`requires` format and lacks issue traceability in `00-pipeline.md`. No committed synthetic example exists; update this reference when a rejected or revised phase prompt is available.

> **Output actionability:** This skill does not independently assess whether the generated prompt covers all edge cases or is free of gaps. That assessment is delegated to `/ralph-prompt-review` (Step 6 of Final output). Do not substitute your own informal quality judgment for that skill — invoke it as specified.

---

## Final output

**Idempotency guard:** Before writing, check whether a file at `prompts/phase-NN-<slug>.md` already exists using the Glob tool (`Glob("prompts/phase-NN-*.md")`). If a match is found, stop and ask:

> "A prompt file already exists at `prompts/<matched-path>`. Overwrite? (yes/no)"

Do not write until the user confirms. If they say no, stop and inform them no file was written.

Write the complete prompt to `prompts/phase-NN-description.md` using the Write tool, where `NN` is zero-padded (01, 02, …) and `description` is a short kebab-case slug (e.g. `prompts/phase-05-slack-notifications.md`). After writing:

1. Silently check that every section is present and non-empty
2. Report any gaps found and how you resolved them, or confirm it is complete

### Also write `prompts/phase-NN/00-pipeline.md` and step files

Always create the pipeline directory alongside the phase prompt.
**Both outputs are required — the phase prompt alone is not sufficient for `/ralph-pipeline` to run.**

**Step 1 — Write `prompts/phase-NN/00-pipeline.md`:**

Decide how many steps the pipeline needs. A single step containing all deliverables is fine
for a cohesive unit of work. Split into multiple steps only when deliverables are clearly
independent and benefit from separate iterations.

```yaml
phase: "NN"
description: "<phase description>"
max_iterations_per_step: <N>   # --max-iterations passed to each ralph-loop call; default 5 if omitted
max_retries_per_step: 2        # times a step is retried when per-step tests fail

issues:
  resolved: [<issue numbers that this phase fully closes — from Q4a>]
  partial: []          # issue numbers only partially addressed — will receive a progress comment

steps:
  - id: "01-<slug>"          # slug describes the work, e.g. "bug-fixes-and-tests"
    produces:
      - "01-<slug>"          # REQUIRED: always include the step id itself as the first produces token
                             # so that downstream requires: ["01-<slug>"] references resolve correctly
      - <additional tokens from Q4b, format: "file/path.ext: description">
    requires: []
  # add more steps only if deliverables are independent

tests:
  per_step: "<from Q10 self-verification — the per-file check>"
  full_suite: "<project-defined full-suite command>"
```

**Choosing `max_iterations_per_step`:**

Always set this field explicitly — never rely on the default of 5.

| Phase complexity | Recommended value | When it applies |
|-----------------|-------------------|-----------------|
| Simple config or docs edits | 5 | Static files, no live operations |
| Backend code + <test-runner> tests | 7 | New routes, DB changes, test authoring |
| Infra + `tofu apply` | 10 | Writing TF, validating, applying, verifying live resources |
| Multi-tool setup or live GCP operations | 10–15 | IAM bindings, Cloud Build triggers, anything that may fail at apply time and need iterative fixes |

If a step involves running a live operation (e.g. `tofu apply`, `gcloud` commands, deploying a service), always set at least 10 — failures at apply time require diagnosis and correction iterations that static file-write steps do not.

**Step 2 — Write a matching step file for every `id` declared in `00-pipeline.md`:**

Each step file lives at `prompts/phase-NN/<id>.md` (the filename must exactly match the
`id` field). It contains the full work spec for that step — either a single deliverable or
all deliverables if the pipeline has one step. Include the self-verification commands and
a DONE signal scoped to that step's work.

**Step 3 — Verify the files match:**

```bash
ls prompts/phase-NN/
# Expected: 00-pipeline.md plus one .md file per step id declared in it
```

If any step file is missing, write it before finishing.

**Step 4 — Register the phase in `prompts/phases.yaml`:**

Append a new entry to `prompts/phases.yaml`:

```yaml
  - id: "NN"
    name: "<short phase name from Q1, title-cased>"
    summary: "<one sentence: what this phase builds or fixes>"
    directory: "prompts/phase-NN"
    created: "<today YYYY-MM-DD>"
    completed: null
    status: available
```

**Step 5 — Write `prompts/phase-NN/README.md` if manual steps were identified in Q12b:**

If Q12b identified any manual prerequisites or post-pipeline steps, write a `README.md` into
the phase directory. This is the operator guide — it is read by the human, not by the agent.

Structure the file as:

```markdown
# Phase NN — <Phase Title>

<One sentence: what this phase does and why the manual steps are needed.>

**Complete all manual steps below before running `/ralph-pipeline prompts/phase-NN`.**

---

## Manual step 1 — <Name>

<When: "before running the pipeline" / "before step NN runs" / "after pipeline completes">

<Why this cannot be automated: e.g. "requires OAuth browser flow", "GCP Console only">

1. <Numbered instruction>
2. <Numbered instruction>

**Verify:**
` `` `bash
<CLI command to confirm the step succeeded>
# Expected: <what success looks like>
` `` `

---

## Manual step 2 — <Name>
...

---

## Pipeline execution order

Once manual steps are complete:

` `` `bash
/ralph-pipeline prompts/phase-NN
` `` `

| Step | What it does | Done when |
|------|-------------|-----------|
| `01-<slug>` | <description> | <completion condition> |
...
```

If Q12b found no manual steps, skip Step 5 entirely — do not create an empty README.

---

**Step 6 — Run mandatory quality review (REQUIRED — do not skip):**

After all files are written and registered, run `ralph-prompt-review` against the newly created phase directory. This step is mandatory — do not proceed to the run command until it is complete.

1. Read `.claude/skills/ralph-prompt-review/SKILL.md` and follow its instructions exactly, passing `prompts/phase-NN/` as the target. Execute Steps 1–4 of the review skill (identify target → read for calibration → score 9 dimensions → write report).

2. Present the full report to the user (summary table + per-dimension findings + verdict).

3. If the verdict is **Ready to run**: proceed directly to Step 7 (run command reminder).

4. If the verdict is **Needs improvement** or **Not ready**: ask the user using `AskUserQuestion`:

   > "The review found gaps in the prompt. Would you like me to apply the suggested fixes before we run the pipeline?"

   Present two options:
   - **Apply fixes** — apply the targeted edits now, then re-confirm the improved dimensions
   - **Skip fixes** — proceed without fixing (user accepts the gaps)

   If the user chooses **Apply fixes**: execute Step 5 of the review skill (targeted `Edit` calls for each ⚠️/❌ dimension only). After applying, confirm which dimensions improved.

   **Example fix output format for each gap found:**

   ```
   #### Q3 gap — Deliverables not enumerated ⚠️
   **Evidence:** "What to build: Add the label role editor and make it work."
   **Fix:**
   Add a ## Deliverables section listing each output as a numbered item:
   1. Create `<source-dir>/labelRoles.js` — getLabelRoles function
   2. Update `<source-dir>/index.js` — POST /admin/label-roles route
   3. Create `test/labelRoles.test.js` — 3 <test-runner> test cases
   ```

5. Do not apply any fix the user has not approved. Do not rewrite sections that scored ✅.

### Output template for review report (Step 6)

The review report produced in Step 6 must follow this format exactly:

```
## ralph-prompt-review: prompts/phase-NN/

| ID | Dimension | Score | Finding |
|----|-----------|-------|---------|
| D1 | Context | ✅ | Context section present and references prior phases |
| D2 | Deliverables | ⚠️ | Deliverables listed in prose, not as a table |
| ... | ... | ... | ... |

### Findings (⚠️ and ❌ only)

#### D2 — Deliverables ⚠️
**Evidence:** "<exact quote from the prompt under review>"
**Fix:**
<the exact text to add, formatted as it would appear in the prompt>

### Verdict

**Verdict:** Ready to run / Needs improvement / Not ready
```

**Verdict field values (exactly one applies):**
- `Complete` — all files written, review passed or gaps accepted, commit and push done
- `Needs clarification` — one or more Q&A answers marked `[VERIFY]` that user has not yet confirmed
- `Blocked by user input` — user declined to proceed at plan confirmation or declined overwrite

**Review verdict selection rules:**
- **Ready to run** — 0 ❌ and ≤2 ⚠️ across all dimensions
- **Needs improvement** — any ❌, or ≥3 ⚠️ across all dimensions
- **Not ready** — ≥2 ❌ in core dimensions (Deliverables, Verification, or Constraints)

---

**Step 6b — Commit and push the phase files:**

After the quality review is complete (and any approved fixes applied), commit and push all newly created phase files to `main`:

```bash
git add prompts/phase-NN-<slug>.md prompts/phase-NN/ prompts/phases.yaml
git commit -m "feat(phases): add phase NN — <short phase description>"
git push origin main
```

Replace `NN` with the zero-padded phase number, `<slug>` with the kebab-case slug used in the filename, and `<short phase description>` with the phase goal from Q1 (max 8 words).

---

**Step 7 — Remind the user of the run command:**

```bash
/ralph-pipeline prompts/phase-NN
```

---

## Error handling

- **Phase directory not found:** emit `ERROR: directory <path> not found — check the phase name` and stop.
- **Template file missing:** emit `ERROR: required template file <name> not found in <path>` and stop.
- **`gh issue list` auth failure:** emit `ERROR: gh auth failed — run 'gh auth login' and retry` and stop. Do not proceed with Q4a until authentication is confirmed.
- **Glob returns no match for `prompts/phase-NN-*.md`:** treat as new phase — no idempotency prompt needed; proceed to write.
- **Write tool blocked (file exists, user declined overwrite):** emit `INFO: no files written — user declined overwrite` and stop.
- **`prompts/phases.yaml` not found:** emit `ERROR: prompts/phases.yaml not found — cannot register phase` and stop before Step 4.
