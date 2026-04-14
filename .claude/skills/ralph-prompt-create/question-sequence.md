# Ralph Prompt Create — Question Sequence (Q1–Q12)

Read this file in full before asking the first question. Work through every question in order. Never skip a question — every answer shapes a different section of the final prompt.

Work through every question below in order. Never skip a question — every answer shapes a different section of the final prompt. If you can confidently infer an answer from context already provided, state your inference and ask the user to confirm or correct it — do not silently assume.

---

**Q1 — Phase goal**
> What is this phase trying to accomplish? Describe it in one or two sentences.

*Drives: Context section title and opening paragraph.*

---

**Q2 — Current system state**
> What already exists that this phase builds on? (e.g. deployed services, completed workflows, infra already in state)

*Drives: Context — "prior phases" summary, what the agent must know before starting.*

---

**Q3 — Protected scope**
> What must this phase NOT change? List any files, services, or infra that are off-limits.

*Drives: Context "must not be modified" call-out + Constraints "No changes to" bullet.*

---

**Q4 — Deliverables**
> What files will be created or modified? For each one, give the path and whether it is a Create, Update, or Delete.

*Drives: the "What to build" deliverables table. If the user lists them in prose, convert to table rows.*

---

---

**Q4a — GitHub issue validation**

Every deliverable must be traceable to an open GitHub issue before the phase can be written.

1. Fetch all open issues:
   ```bash
   gh issue list --state open --json number,title,body,labels --limit 100
   ```
2. For each major deliverable group (from Q4), find the best-matching open issue by comparing the deliverable description against issue titles and bodies.
3. **If a match is found:** record the issue number. Inform the user:
   > "Deliverable '<name>' maps to issue #N: <title>."
4. **If no match is found:** block and present a suggested issue for user approval:
   > "No open issue found for deliverable '<name>'. Suggested issue:
   > **Title:** <derived from the deliverable description>
   > **Body:** <2–3 sentences describing the problem and goal>
   > **Label:** <most appropriate label — e.g. harness, enhancement, feature>
   > Shall I raise this issue now?"

   **Idempotency guard:** Before creating a GitHub issue, search for an existing open issue with the same title to avoid duplicates:
   ```bash
   gh issue list --state open --search "<derived title>" --json number,title
   ```
   Only create the issue if no existing issue with the same title is found.

   On confirmation, create it:
   ```bash
   gh issue create --title "<title>" --body "<body>" --label "<label>"
   ```
   Record the returned issue number. Do **not** proceed until every deliverable has a mapped issue.

5. Classify each mapped issue:
   - **resolved** — this phase fully delivers on the issue; it will be closed on pipeline completion
   - **partial** — this phase only partially addresses the issue; it will receive a progress comment

   Ask the user to confirm the classification for any issue where it is not obvious.

6. Store two lists: `resolved_issues` and `partial_issues` (issue numbers). These will be written into `00-pipeline.md` under the `issues:` field.

*Drives: `issues:` field in `00-pipeline.md`.*

---

**Q4b — Step dependencies (pipeline metadata)**
> For each deliverable file, what does it **produce** that later steps depend on (e.g. exported
> functions, API routes, schema fields), and what does it **require** from earlier steps?
> Use the format: `<file>: <thing>` (e.g. `db.js: getActivePrompt`, `index.js: POST /orchestrate`).
>
> This populates the `produces`/`requires` fields in `00-pipeline.md` for `ralph-pipeline`.

*Drives: produces/requires metadata in the pipeline config.*

---

**Q4c — UI/frontend detection**

After reviewing the deliverables from Q4, check whether any involve UI or frontend work. A deliverable is UI/frontend if it:
- Creates or modifies an HTML template, EJS/Handlebars/Pug file, or static page
- Adds or changes a frontend component, form, or interactive element
- Introduces new CSS or client-side JavaScript visible to the user

If **no** deliverables are UI/frontend, skip Q4c entirely and proceed to Q5.

If **any** deliverable is UI/frontend:
1. Derive a kebab-case feature slug from the phase goal and UI deliverable names (e.g. `board-config-columns`, `label-role-editor`).
2. Check whether `docs/ux/<slug>.md` already exists using the Glob tool (`docs/ux/<slug>.md`).
3. **If the file does NOT exist:**
   - Notify the user: "This phase includes UI changes. I'll generate Gherkin/BDD acceptance scenarios before we continue — these will be added to the Self-verification section."
   - Read `.claude/skills/gherkin/gherkin-scenarios/SKILL.md` and follow the instructions there, passing the phase goal (Q1) and the list of UI deliverables (Q4) as context so it can skip its own feature-identification step.
4. **If the file already exists:**
   - Notify the user: "A Gherkin scenarios file already exists for this feature (`docs/ux/<slug>.md`). I'll review it against the current deliverables before we continue."
   - Read `.claude/skills/gherkin/gherkin-review/SKILL.md` and follow the instructions there, passing the existing file path so it can skip its own file-identification step.
5. Wait for the sub-flow to complete and confirm the file path.
6. Store the file path — it will be referenced in Q10 (Verification) under a `### UI acceptance criteria` heading.

*Drives: UI acceptance criteria in the Self-verification section.*

---

**Q5 — API and data shapes**
> For any service endpoints or data transformations in the deliverables: what does the request look like, and what does the response look like? Include error cases.

*Drives: Deliverable specifications — request/response schemas. If no services are involved, confirm and skip.*

---

**Q6 — Processing logic**
> For any non-trivial logic (extraction, deduplication, matching, routing): what are the steps in order? Are there specific algorithms, models, or rules to follow?

*Drives: "Processing steps (implement in this order)" within deliverable specs.*

---

**Q7 — Configuration and secrets**
> What environment variables, secrets, or external credentials does this phase need? Where does each one come from (Secret Manager, env, hardcoded default)?

*Drives: Environment variables table in deliverable specs.*

---

**Q8 — Tooling constraints**
> Are there specific CLI tools, runtimes, package managers, or Claude models that must (or must not) be used? Include versions if they matter.

*Drives: Constraints section — tooling, model choices.*

---

**Q9 — Security requirements**
> What are the security rules for this phase? (e.g. auth check order, what must never be logged, how secrets are passed, data handling rules)

*Drives: Constraints — Security bullet.*

---

**Q9b — Test coverage (mandatory)**

Every phase must ship with tests. This question is never skipped.

> What tests need to be created or updated to cover this phase?
>
> **For API/backend changes:** which <test-runner> test file(s) in `<test-dir>/` will be updated or created? What new test cases cover the new behaviour and the error paths?
>
> **For UI/frontend changes:** which <e2e-runner> spec(s) in `<e2e-test-dir>/` will be updated or created? What user interactions and visible outcomes will be asserted?
>
> **For bug fixes:** what regression test would have caught this bug *before* the fix? Where does it live?
>
> **For harness changes** (skills, hooks, Python scripts — no orchestrator code touched): add a shell test script (e.g. `scripts/test-<feature>.sh`) that runs the changed behaviour, asserts output, and exits 0 on success. If truly no shell test surface exists (e.g. pure markdown skill file), add a deliverables row with action `"No test file — harness only; verified by self-verification shell commands"` and state the rationale explicitly in the Constraints section.
>
> **For new skill files** (`.claude/skills/*/SKILL.md`): the skill must use binary criteria throughout — no subjective thresholds. Before marking the deliverable complete, verify the new skill file passes the RS checklist in `docs/skill-design-standards.md` — all 4 questions must answer Y.
>
> If a deliverable has no testable surface (e.g. a docs-only change), state that explicitly — it must still be listed in the "What to build" table with action "No test needed — docs only".

**Rules:**
- Test files are first-class deliverables. Every test file must appear as a row in the "What to build" table.
- For **backend and harness phases**, per-step verification uses `npm test` only — `npm run test:e2e` cannot run locally (requires deployed Cloud Run + <datastore>). `npm run test:e2e` appears only in `full_suite` in `00-pipeline.md`.
- For **frontend phases** (changes to HTML, <ui-framework>, <e2e-runner> specs), per-step verification uses the full combined command: `<project-defined full-suite command>`
- A phase with zero new or updated tests is incomplete. Do not accept "out of scope" for tests unless the phase is docs-only.

*Drives: test rows in the deliverables table; Self-verification section; `full_suite` in `00-pipeline.md`.*

---

**Q9c — Test prerequisites (seed data and environment state)**

> Does this phase change any API routes, <datastore> collections, or data models that integration
> tests depend on?

If the answer is **no**, skip Q9c entirely and proceed to Q10.

If the answer is **yes**, ask:

> What seed data or environment state must exist in <datastore> (or elsewhere) before the test
> suite can pass? For example: board config documents, prompt documents, user records, or
> specific collection structure.

Capture the answer as a `## Test Prerequisites` section in the generated step file(s), placed
immediately before the `## Self-verification` section:

~~~markdown
## Test Prerequisites

Before running tests, the following state must exist:

- <item 1 — e.g. "At least one board config document in <datastore> `boardConfigs` collection">
- <item 2 — e.g. "Active extraction prompt in <datastore> `prompts` collection (run POST /admin/seed)">

To set up:
```bash
<setup command, e.g. curl -X POST $ORCHESTRATOR_URL/admin/seed -b "$COOKIE">
```
~~~

Also ask:

> Should a dedicated setup step be added to `00-pipeline.md` to run this seed/setup before
> the integration tests? (Recommended when setup is non-trivial or automated.)

If yes: add a step with `id: "00-seed-setup"` to the pipeline manifest, with `requires: []`
and listed before the steps that depend on it. The step file should contain only the seed
commands and a verification check.

*Drives: `## Test Prerequisites` section in step files; optional seed step in `00-pipeline.md`.*

---

**Q10 — Verification**
> How will you know each deliverable is correct? Is there a test file, a curl command, or a specific output to check? What does success look like?

*Drives: Self-verification section — copy-paste ready commands.*

The Self-verification section must always end with the full test suite command:

```bash
# Run <test-runner> (always required locally)
cd orchestrator && npm test
# Expected: all tests pass

# Run full suite including E2E — for frontend phases only; backend/harness phases skip E2E per-step
# (E2E runs via full_suite in 00-pipeline.md after deploy)
# <project-defined full-suite command>
```

If Gherkin scenarios were generated in Q4c, append a reference to the saved file under a `### UI acceptance criteria` heading, e.g.:

```markdown
### UI acceptance criteria

See `docs/ux/board-config-columns.md` for full Gherkin scenarios.
All scenarios in that file must pass before this deliverable is considered complete.
```

Do not ask the user about them again — they are already confirmed.

### Per-step test authoring rules

When writing `per_step` commands in `00-pipeline.md`, follow these rules to prevent false positives and scope violations:

#### Rule 1 — Use `! grep -q` for absence assertions, never `grep -c`

When the deliverable state is the *absence* of a string, the test must use `! grep -q`:

```bash
# CORRECT — exits 0 when phrase absent (success), exits 1 when phrase present (regression)
! grep -q 'some-phrase-that-must-not-exist' path/to/file

# WRONG — exits 1 when phrase absent (i.e., fails in the correct deliverable state)
grep -c 'some-phrase-that-must-not-exist' path/to/file
```

**Root cause:** `grep -c` exits 0 when count ≥ 1 and exits 1 when count = 0. For an absence assertion, success (count = 0) produces exit 1 — a test failure. Always use `! grep -q` for absence checks.

*First identified in Phase 50 issue #86.*

#### Rule 2 — Scope per_step to the current step's deliverables only

The global `tests.per_step` in `00-pipeline.md` runs after every step. It must only reference deliverables that exist after step 01 completes. If a later step produces a file or phrase that does not exist until that step runs, that check must not be in the global per_step.

```yaml
# WRONG — the grep 'Step 5.5' check only passes after step-02 completes
tests:
  per_step: "uv run python -m py_compile script.py && grep 'Step 5.5' skill.md"

# CORRECT — only step-01 deliverables in per_step; step-02 verified in its own step file
tests:
  per_step: "uv run python -m py_compile script.py && grep -q 'error_type' script.py"
```

If a phase has multiple steps with non-overlapping deliverables, verify later-step deliverables only in those step files' `## Self-verification` sections, not in the global `per_step`.

*First identified in Phase 51 issue #87.*

---

**Q11 — Iteration grouping**
> How many major deliverables are there, and which ones can be grouped into one iteration? (Rule: one group per iteration; a group can contain multiple small related files.)

*Drives: Loop execution strategy — the numbered iteration group list.*

---

**Q12 — Documentation updates**
> What needs to be updated in docs, README, or ADRs? Should any prior sections be marked superseded?

*Drives: Documentation deliverable spec and runbook content.*

**Documentation placement rules:**
- `docs/deployment.md` — phase runbooks, deployment steps, curl smoke-test commands, secret setup. Add a new `## Phase N — <title>` section here.
- `CLAUDE.md` — only repo-working conventions: project overview, repo structure, workflow rules, tool constraints. Do **not** add phase runbooks or deployment steps to `CLAUDE.md`.
- If a deliverable would have gone into `CLAUDE.md` as a runbook, put it in `docs/deployment.md` instead.

**Always check `docs/architecture.md` explicitly.** Ask whether either Mermaid diagram needs updating — do not assume the answer is no. Common triggers:
- Any auth change (new flow, new participants, token → cookie, etc.)
- New external services added (<datastore>, queues, caches, etc.)
- New routes or data flows visible outside the orchestrator
- Changes to how Claude is called (models, inputs, sequence of calls)
- Changes to how <external-service> is written to

Even if the change is minor (e.g. a single node label update), include `docs/architecture.md` as a deliverable rather than leaving the diagrams stale.

---

**Q12b — Manual prerequisites**

> Does this phase require any steps that cannot be automated — for example: OAuth flows,
> GCP Console configuration, GitHub settings, one-time IAM grants, or third-party app
> installations?

If the answer is **no**, skip Q12b entirely and proceed to "After all questions are answered".

If the answer is **yes**:
1. List each manual step with its trigger (e.g. "must be done before `tofu apply`",
   "done once after pipeline completes").
2. Note it — a `README.md` will be written to `prompts/phase-NN/` in the Final Output section
   (Step 5) documenting these steps for the human operator.

*Drives: `prompts/phase-NN/README.md` — operator guide for steps the pipeline cannot perform.*