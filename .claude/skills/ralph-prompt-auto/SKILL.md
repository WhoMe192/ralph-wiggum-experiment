---
name: ralph-prompt-auto
description: >
  Automatically create a ralph-loop phase from GitHub issues without Q&A. Infers all 12
  answers from issue content, codebase, and phase corpus. Triggers: '/ralph-prompt-auto 34',
  'auto-create phase from issue 34', 'generate phase for issues 34 35'.
argument-hint: "<issue-number> [issue-number...]"
disable-model-invocation: true
allowed-tools: AskUserQuestion, ToolSearch, Bash, Read, Write, Glob, Grep, Edit, Agent, Skill
---

# Ralph Prompt Auto

> **Before first use:** confirm `CLAUDE.md` §Tech Stack is populated and accurately
> lists the project's languages, frameworks, and key directories. This skill reads that
> section to classify phase type (infra / backend / frontend / harness) and to decide
> which source directories to inspect for existing patterns. If the Tech Stack section is
> empty or out of date, the skill will produce shallow or misdirected phases. Corpus query
> is optional — skipped gracefully if `prompts/phase-corpus.jsonl` is empty or missing.
>
> **Source-directory scan:** the skill identifies candidate source dirs by scanning
> top-level directories (excluding `.claude`, `.devcontainer`, `.git`, `node_modules`,
> `prompts`, `docs`, `.github`, `dist`, `build`, `.venv`, `__pycache__`) and checking for
> manifest files (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`,
> `Gemfile`, `build.gradle`, etc.). Treat each matched directory as a possible work site.

Creates a complete ralph-loop phase from one or more GitHub issues, inferring all prompt content from the issue(s), codebase, and completed phase corpus. The human's only checkpoint is the `ralph-prompt-review` report produced at the end.

## Inputs

| Input | Required / Optional | Source |
|-------|---------------------|--------|
| Issue number(s) | **Required** — one or more integers, space-separated | `$ARGUMENTS`, e.g. `/ralph-prompt-auto 34 35` |
| Codebase context | Optional — inferred automatically | `docs/architecture.md`, `CLAUDE.md` §Tech Stack, top-level source dirs (see banner above) |
| Phase corpus | Optional — used if `prompts/phase-corpus.jsonl` exists | corpus-query subagent |

If no issue numbers are provided, the skill prompts for them via `AskUserQuestion` (see Step 1). All other inputs are inferred — the human never needs to supply them.

---

## Design principle: cautious by default

When uncertain whether something belongs, include it marked `[VERIFY — may not be needed]` rather than omitting it. An omission is invisible; a flagged inclusion is easy to remove. The pre-run review will surface all unresolved markers as ⚠️.

---

## Success and failure criteria

**Success:** All 5 phase files written (prompt .md, 00-pipeline.md, at least one step file, phases.yaml entry, README if applicable); ralph-prompt-review verdict is Ready or Needs improvement with no blocking ❌ in B, V, or T; phase committed and pushed.

**Failure (stop and report):** Issue fetch fails, any issue body is too short to infer a prompt, or file write exits non-zero.

---

## Step 1 — Parse issue numbers

Extract all issue numbers from the invocation args (e.g. `/ralph-prompt-auto 34 35 41`).

If no issue numbers are provided, fetch `AskUserQuestion` (ToolSearch select:AskUserQuestion) and ask:
> "Which GitHub issue number(s) should this phase be based on? Provide one or more, space-separated."

Fetch all issues in parallel:
```bash
gh issue view <N> --json number,title,body,labels
```

**Empty body guard:** If any issue's `body` field is null, empty, or fewer than 20 characters, emit:
"Error: Issue #N body is too short to infer a phase prompt. Add acceptance criteria and context to the issue body first." and stop.

Store: `issue_numbers[]`, `issue_titles[]`, `issue_bodies[]`, `issue_labels[]` (flattened union of all label names).

---

## Step 2 — Classify phase type

From the union of all issue labels and body content, assign one or more types:

| Type | Signals |
|---|---|
| `infra` | label `infra`; body mentions infrastructure-as-code files (match against tools declared in `CLAUDE.md` §Tech Stack) |
| `backend` | label `enhancement`/`bug`; body mentions routes, data stores, middleware, server framework (match against `CLAUDE.md` §Tech Stack) |
| `frontend` | body mentions UI components, rendering, browser-side frameworks, E2E browser tests (match against `CLAUDE.md` §Tech Stack) |
| `bug-fix` | label `bug`; body describes broken behaviour + expected behaviour |
| `harness` | label `harness`; body mentions ralph-loop, skills, hooks, telemetry |
| `docs-only` | body mentions only `.md` files; no code changes |

If multiple types apply, note all — the phase is `mixed`. A `mixed` phase draws exemplars from each type bucket.

---

## Step 3 — Select exemplar phases

Check whether `prompts/phase-corpus.jsonl` exists (also check `corpus_entry` in phases.yaml for a fast negative):

```bash
test -f prompts/phase-corpus.jsonl && echo EXISTS || echo ABSENT
```

**If corpus exists:** invoke the corpus-query subagent via the `Agent` tool to retrieve the 2 best-matching exemplars for each identified phase type. The subagent runs in an isolated context — the parent never loads the full corpus.

Invocation pattern for each type (e.g. `harness`):

```
Agent tool:
  subagent_type: general-purpose
  description: "query corpus for <type> exemplars"
  prompt: |
    Follow the instructions in .claude/skills/corpus-query/SKILL.md.
    Query: return the top 2 entries where type = '<type>', ordered by review_total DESC.
    Return only the raw JSON objects, one per line, nothing else.
```

Parse each returned JSON line as an exemplar record. Use these records in place of the
exemplar phase files for produces/requires patterns, verification command styles, and
constraint wording.

For mixed phases, run one Agent invocation per type and deduplicate results.

**If corpus is absent** (bootstrap path), use these hardcoded exemplars by type:

| Type | Primary exemplar | Secondary exemplar |
|---|---|---|
| `infra` | `prompts/completed/phase-23-infra-cleanup.md` + `prompts/completed/phase-23/` | `prompts/completed/phase-21/` |
| `backend` | `prompts/completed/phase-10/` | `prompts/completed/<prior-backend-phase>.md` |
| `frontend` | `prompts/completed/phase-12/` | `prompts/completed/phase-20/` |
| `bug-fix` | `prompts/completed/phase-11-bug-fixes.md` | `prompts/completed/phase-16/` |
| `harness` | `prompts/completed/phase-22/` | `prompts/completed/phase-18/` |
| `docs-only` | any phase with a docs-only step | — |

Read the selected exemplar files. They are the reference for produces/requires patterns, verification command styles, iteration grouping, and constraint wording.

---

## Step 4 — Determine next phase number

**Idempotency check:** Before creating a new phase, check whether any existing phase already references these issue numbers:

```bash
grep -A5 "issues:" prompts/phases.yaml | grep -E "^\s+- [0-9]"
```

Scan the output for any of the input issue numbers. If a match is found, fetch `AskUserQuestion` and ask:
> "Phase <NN> in phases.yaml already references issue #<N>. Create a new phase anyway, or use the existing one?"

If the user chooses the existing phase, stop here and point them to it. Do not create a duplicate.

```bash
# Find highest current phase id in the registry
grep "^  - id:" prompts/phases.yaml | tail -1
```

Next phase = highest id + 1, zero-padded to 2 digits.

---

## Step 5 — Infer Q1–Q12

Work through each question using the sources below. Track confidence (high / low) for Q1, Q4, Q5, Q6.

**Confidence thresholds:**
- **High confidence:** the inferred value has ≥2 corroborating sources (e.g. issue body + codebase grep result, or issue body + exemplar pattern). Write the value without a marker.
- **Low confidence:** only 1 source, or sources conflict with each other. Mark the inferred value with `[VERIFY]` and add a `<!-- LOW CONFIDENCE: <reason> -->` comment on the line above.

**Q1 — Goal**
- Single issue: take the `issue_title` verbatim as the goal root; expand with the first sentence of `issue_body` if it adds specificity.
- Multiple issues: if all titles share a common verb-phrase (e.g. all are "bug: X fails when Y"), combine as "Fix: [shared pattern]". If titles have no shared verb-phrase, express as "Address N outstanding issues: <title1>, <title2>, …"
- *Low confidence (flag in summary)*: multiple issues where no two titles share a common noun or verb.

**Q2 — Current state**
- Read `prompts/phases.yaml` — last 3 completed phases
- Read `docs/architecture.md` — first 60 lines (system overview)
- Read `CLAUDE.md` — Project Overview and Repository Structure sections
- Note any files explicitly mentioned in issue bodies

**Q3 — Protected scope**
- Baseline from CLAUDE.md: test suite commands, trunk-based workflow, CLAUDE.md itself
- From exemplar's "No changes to" constraint list for this type
- Any files mentioned in issue bodies as off-limits
- **Cautious:** include the exemplar's full protected list even if not all items are obvious from the issue

**Q4 — Deliverables**
1. Extract any file paths explicitly named in issue bodies
2. Grep codebase for files in affected areas:
   ```bash
   # Example: if issue mentions "board config"
   grep -rl "<domain-keyword>" <source-dir>/ --include="*.<ext>" | head -10
   ```
3. Apply type defaults:
   - `backend`: always add a test file row in `<test-dir>/` and a `docs/deployment.md` update
   - `infra`: always add `docs/architecture.md` update
   - `frontend`: always add a E2E spec row in `<e2e-test-dir>/`
   - `bug-fix`: always add a regression test row
4. Mark grep-inferred files as `Update — [VERIFY — may not be needed]`
5. Order: schema/infra → service code → tests → docs
6. Check for UI deliverables (any `.html`, `.ejs`, UI component): if found, note for Q4c

**Q4a — Issue mapping**
- Map each deliverable group to the issue(s) it satisfies
- Default to `partial` when uncertain whether a phase fully closes an issue
- Accumulate all input issue numbers into `issues.resolved` (partial ones into `issues.partial`)

**Q4b — Step dependencies**
- Derive topological order from deliverable types: DB/schema → service layer → tests → docs
- Pull produces/requires patterns from exemplar's `00-pipeline.md`
- One step per independent deliverable group; merge if files overlap; max 5 steps

**Q4c — UI detection**
- If any deliverable is UI/frontend: check whether `docs/ux/<slug>.md` exists (slug = kebab-case of the UI feature name)
- If not: note that Gherkin scenarios should be generated (but do not block — note it as `[VERIFY — gherkin scenarios needed]` in the step file)

**Q5 — API shapes**
- Read `<source-dir>/index.js` for existing route handlers
- If modifying an existing route: show current shape + what changes
- If adding a new route: derive shape from issue description; mark fields inferred from context as `[VERIFY]`
- Include error shape: `{ success: false, error: "<message>" }`

**Q6 — Processing logic**
- Extract numbered steps from issue body if present
- Read affected source files for current flow
- Apply exemplar processing pattern for this type (e.g. Claude extraction → dedup → resolve for backend)

**Q7 — Config/secrets**
```bash
grep -r "process\.env\." <source-dir>/ --include="*.js" -h | sort -u | head -20
```
Standard set from CLAUDE.md baseline; add any new secrets named in the issue.

**Q8 — Tooling constraints**
- Copy directly from CLAUDE.md: OpenTofu not Terraform, `uv run python` not `python3`, Node.js version
- Add type-specific constraints from exemplar (e.g. "always `tofu`, never `terraform`" for infra phases)

**Q9 — Security**
- Copy auth check order from existing `<source-dir>/index.js` middleware chain
- Add any security rules mentioned in the issue

**Q9b — Test coverage**
- `backend`: find matching unit-test file in `<test-dir>/`; derive new test cases from the route behaviour described in the issue
- `frontend`: find matching E2E spec in `<e2e-test-dir>/`
- `bug-fix`: construct the regression test from the reproduction steps in the issue body
- `harness`: for changes to skills, hooks, or Python scripts — add a shell test script (e.g. `scripts/test-<feature>.sh`) that exercises the changed behaviour (run it, assert output, check exit code). If truly no shell test surface exists, add a deliverables row with action `"No test file — harness only; verified by self-verification shell commands"` and state the rationale explicitly in the Constraints section
- **Cautious:** if no obvious test surface but not docs-only, include a test row marked `[VERIFY — may not be needed]`

**Q10 — Verification**
Apply mandatory checks by file type (from `ralph-prompt-create` SKILL.md verification table):
- `.js` → `node --check <file>`
- `.tf` → `cd infra && tofu validate`
- `.sh` → `bash -n <file>`
- `.json` → `python3 -m json.tool <file> > /dev/null && echo OK`
- Live service → `curl -s "$APP_URL/health"` with `{"ok":true}` expected
- Skill `.md` files that invoke `corpus-query`: use `grep -C5 "corpus-query" <file> | grep -q "Agent tool" && echo OK`
  (Use `-C5` bidirectional context — "Agent tool" may appear before or after "corpus-query" depending on authoring order; `-A2` is position-sensitive and will fail)
- For **backend and harness phases**: end per-step verification with `<project-defined focused-test command>` only. `npm run test:e2e` cannot run locally — it appears only in `full_suite` (00-pipeline.md).
- For **frontend phases**: end per-step verification with the full combined command: `<project-defined full-suite command>`

**Q11 — Iteration grouping**
- ≤3 closely related files → single step
- Infra + code → two steps; code + tests + docs → two or three steps
- Multiple issues' deliverables: treat each issue as a candidate step; merge if files overlap
- Cap at 5 steps

**Q12 — Docs updates**
- Always check `docs/architecture.md` against trigger list: new auth flow, new external service, new route, changed AI/LLM call pattern, changed integration write path. **Cautious:** if any trigger is plausible, include `docs/architecture.md` as `Update — [DIAGRAM UPDATE REQUIRED — verify scope]`
- Add `## Phase N — <Title>` section to `docs/deployment.md` if phase deploys anything; mark `[VERIFY — may not be needed]` if deployment is uncertain
- Never put runbooks in CLAUDE.md

**Q12b — Manual prerequisites**
- Scan issue bodies for: "GCP Console", "OAuth", "IAM", "one-time", "manually", "browser"
- **Cautious:** if any such phrase appears, set `has_manual_prereqs = true`

---

## Step 6 — Write all phase files

Use the section structure from `.claude/skills/ralph-prompt-create/SKILL.md` (Sections 1–7) exactly. All files are written with the Write tool.

### File 1: `prompts/phase-NN-<slug>.md`

Slug = kebab-case of the phase goal (max 4 words). Write the complete prompt using Sections 1–7 from `ralph-prompt-create`. The Loop Execution Strategy section (Section 6) **must** include the full Concerns Log block as specified in `ralph-prompt-create` SKILL.md.

Low-confidence answers are written with their best-guess content plus a `<!-- LOW CONFIDENCE: <reason> -->` HTML comment on the line above. These comments are visible in the review report.

### File 2: `prompts/phase-NN/00-pipeline.md`

```yaml
phase: "NN"
description: "<Q1 goal, one sentence>"
max_iterations_per_step: <from complexity table in ralph-prompt-create>
max_retries_per_step: 2

issues:
  resolved: [<issue numbers classified as resolved>]
  partial:  [<issue numbers classified as partial>]

steps:
  - id: "<step-slug>"
    produces:
      - "<step-slug>"        # REQUIRED: always include the step id itself as the first produces token
                             # so that downstream requires: ["<step-slug>"] references resolve correctly
      - <additional tokens from Q4b, format: "file/path.ext: description">
    requires: []
  # additional steps as needed

tests:
  per_step: "<per-file verification command from Q10>"
  full_suite: "<project-defined full-suite command>"
```

### File 3: `prompts/phase-NN/<step-id>.md` (one per step)

Each step file contains the deliverables, processing logic, verification, and DONE signal scoped to that step. Include `## Test Prerequisites` if Q9c identified seed data requirements.

**Every step file must include a `## Concerns log` block** immediately before `## Signal completion`. Use the standard format from ralph-prompt-create Section 6 — append to `prompts/phase-NN/concerns.md`, name all three categories (contradiction, missing-info, assumption), and include the structured entry template with `**Category:**`, `**Prompt section:**`, `**What I encountered:**`, `**What I did:**`, `**Suggested fix:**` fields. Do not use the inline `[OPEN]/[RESOLVED]` format.

ralph-pipeline runs each step file as its own ralph-loop iteration — the concerns log instruction in the top-level prompt is not visible to the step agent. It must appear in every step file.

### File 4: `prompts/phases.yaml` — append entry

```yaml
  - id: "NN"
    name: "<short phase name, title-cased>"
    summary: "<one sentence>"
    directory: "prompts/phase-NN"
    created: "<today YYYY-MM-DD>"
    completed: null
    status: available
```

### File 5: `prompts/phase-NN/README.md` (only if `has_manual_prereqs = true`)

Write a README with `[MANUAL STEP — describe here]` placeholders for each detected manual prerequisite. The human fills this in before running the pipeline.

---

## Step 7 — Verify files were written

```bash
ls prompts/phase-NN/
# Expected: 00-pipeline.md plus one .md file per step id
grep "id: \"NN\"" prompts/phases.yaml
```

If any step file is missing, write it before continuing.

---

## Step 8 — Run pre-run quality review

Read `.claude/skills/ralph-prompt-review/SKILL.md` and follow Steps 1–5 exactly, passing `prompts/phase-NN/` as the target.

Present the full scored report (summary table + per-dimension findings).

**Verdict: Ready to run** — proceed to Step 9.

**Verdict: Needs improvement or Not ready** — fetch `AskUserQuestion` and ask:
> "The review found gaps. Apply fixes before running?"

- **Apply fixes:** execute Step 5 of the review skill (targeted Edit calls for ⚠️/❌ dimensions only). Confirm which dimensions improved.
- **Skip fixes:** proceed to Step 9 with gaps noted.

---

## Step 9 — Commit and push the phase files

After the quality review is complete (and any approved fixes applied), commit and push all newly created phase files to `main`:

```bash
git add prompts/phase-NN-<slug>.md prompts/phase-NN/ prompts/phases.yaml
git commit -m "feat(phases): add phase NN — <short phase description>"
git push origin main
```

Replace `NN` with the zero-padded phase number, `<slug>` with the kebab-case slug used in the filename, and `<short phase description>` with the Q1 goal (max 8 words).

---

## Step 9a — Post traceability comments

After the commit and push in Step 9, post a comment to each source GitHub issue so the issue links back to the phase.

For each issue number in `issue_numbers[]`:

```bash
gh issue comment <NUMBER> --body "This issue is being addressed in phase <NN>.

Phase prompt: \`prompts/phase-NN-<slug>/\`"
```

Replace `<NUMBER>` with the issue number, `<NN>` with the zero-padded phase number, and `<slug>` with the kebab-case slug used in the phase filename.

If `gh issue comment` exits non-zero, log the error to the console and continue to the next issue. Do not abort.

---

## Step 10 — Remind run command and surface low-confidence answers

**Verdict enum** — emit exactly one of these verdicts at the end of Step 10:

| Verdict | Meaning |
|---------|---------|
| `ready` | All 5 files written; ralph-prompt-review passed with no ❌ in B, V, or T. |
| `needs-review` | All 5 files written; review found one or more ⚠️ but no blocking ❌. Human should review before running. |
| `blocked` | Files not fully written, or review found a critical ❌ (in B, V, or T) that was not resolved. Do not run until fixed. |

**Output template:**

```
Phase NN created: prompts/phase-NN/
Verdict: ✅ ready | ⚠️ needs-review | ❌ blocked

To run:
  /ralph-pipeline prompts/phase-NN

Inferred from evidence:
  • Q1 — Goal: "<issue title verbatim>" — source: issue #N title
  • Q4 — <filename>: inferred from `grep -rl <pattern> <source-dir>/` — source: codebase grep
  • Q5 — POST /foo: "<excerpt from issue body describing the route>" — source: issue #N body
```

Include one quoted evidence line per low-confidence answer. For high-confidence answers, evidence lines are optional.

If any low-confidence answers were written, list them:

```
Low-confidence sections (review before running):
  • Q1 — Goal: multiple issues with unrelated themes; synthesised goal may be too broad
  • Q4 — <filename>: inferred from grep, not explicitly named in issue
  • Q5 — POST /foo: new route with no prior art; request shape is a best guess
```

If any `[VERIFY...]` markers remain unresolved in the generated files:

```
Unresolved markers (confirm or remove before running):
  • prompts/phase-NN/01-<slug>.md: [VERIFY — may not be needed] on <source-dir>/foo.js
  • prompts/phase-NN/phase-NN-<slug>.md: [DIAGRAM UPDATE REQUIRED] on docs/architecture.md
```

---

## Standards

The 12-answer inference model follows the question sequence defined in `ralph-prompt-create/SKILL.md` (Q1–Q12). That file is the canonical source for what each question covers and what a complete answer looks like.

Phase type classification signals (infra, backend, frontend, bug-fix, harness, docs-only) are defined in Step 2 of this skill and calibrated against examples in `docs/skill-design-standards.md`.

**Co-update partners** — changes to the shared authoring model must be reflected across all three skills:
- **ralph-prompt-create** — defines the Q1–Q12 question sequence and section structure this skill populates; any new question or structural change here must be mirrored in ralph-prompt-auto's Step 5.
- **ralph-prompt-review** — scores the output this skill produces; if ralph-prompt-auto starts generating a new section, ralph-prompt-review's dimension table must be updated to cover it.

## Calibration examples

| Quality | Reference | Why |
|---------|-----------|-----|
| ✅ Strong | `prompts/completed/phase-52-archived-column-error.md` + `prompts/completed/phase-52/` (generated from issue #85) | All 5 files written; review passed; no unresolved `[VERIFY]` markers; idempotency check prevented re-creation |
| ❌ Weak (ID gap) | Running the skill a second time on the same issue number without the idempotency check — creates a duplicate phase in phases.yaml with a new ID but identical content |
