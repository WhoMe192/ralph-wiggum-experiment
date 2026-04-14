# Skill Output Templates

Canonical output templates for the three skill types used in this project.
Referenced by the OA dimension in `docs/skill-design-standards.md`.

Copy the matching template into your skill's `## Output template` section and customise
the placeholders. Do **not** describe what the output will look like — show a filled-in example.

---

## 1. Assessment / review skills

Skills that score or evaluate an artefact (e.g. `adr-review`, `skill-review`, `ralph-prompt-review`).

```
## <Skill Name>: <artefact-identifier>

| ID | Dimension | Score | Finding |
|----|-----------|-------|---------|
| XX | Name      | ✅    | One-line summary — criterion met, no action needed |
| YY | Name      | ⚠️    | One-line summary — gap identified, improvement recommended |
| ZZ | Name      | ❌    | One-line summary — criterion absent, fix required |

### Findings (⚠️ and ❌ only)

#### YY — Dimension Name ⚠️

**Evidence:** "<exact quote from the artefact under review>"

**Fix:**
<the exact text to add, formatted as it would appear in the artefact>

#### ZZ — Dimension Name ❌

**Evidence:** "This section is absent."

**Fix:**
<the exact text to add, formatted as it would appear in the artefact>

### Verdict

**Verdict:** Optimised / Needs improvement / Major revision
```

**Verdict selection rules:**
- **Optimised** — all dimensions ✅, or ≤2 ⚠️ in low-impact dimensions (ID, SC, CV only)
- **Needs improvement** — any ❌, or ≥3 ⚠️ in any dimension
- **Major revision** — multiple ❌ in RC, RS, OA, or OF

---

## 2. Workflow / action skills

Skills that execute steps with side effects: writing files, committing, posting to GitHub,
calling external APIs (e.g. `smart-commit`, `adr-approve`, `fix-ci`, `corpus-sync`).

**Success output:**
```
### Run complete

**Status:** Success

**Actions taken:**
- Created `docs/adr/008-example.md` from template
- Appended entry to `prompts/phases.yaml`
- Committed: "chore(adr): add ADR-008 example decision"

**Output:** docs/adr/008-example.md
```

**Partial output** (some steps succeeded, at least one did not):
```
### Run complete

**Status:** Partial

**Completed:**
- <step that succeeded>

**Skipped / failed:**
- <step that did not run> — reason: <exact reason>

**Next step:** <what the user must do to resolve>
```

**Blocked output** (skill cannot proceed without user action):
```
### Run blocked

**Status:** Blocked

**Reason:** <exact error message or missing precondition>

**Next step:** <concrete action the user should take>
```

**Already-done output** (idempotency — skill was re-run on unchanged state):
```
### Run complete

**Status:** Already done

**No changes made.** <artefact/state> already matches expected state.
Re-run is safe — no side effects occurred.
```

---

## 3. Dispatcher skills

Skills whose primary action is to read input and route to a sub-skill
(e.g. `gherkin`, `gcp`, `likec4`).

**Normal routing output:**
```
**Mode detected:** <mode-name>
**Routing to:** `<sub-skill-name>`

---

<sub-skill output appears here>
```

**Ambiguous input output:**
```
**Input ambiguous.** Could not determine mode from: "<exact user input>"

**Options:**
- (a) `<mode-1>` — invoke as `/<skill> <mode-1-keyword>`
- (b) `<mode-2>` — invoke as `/<skill> <mode-2-keyword>`

Which mode did you intend?
```

**Unknown mode output:**
```
**Mode not recognised:** "<exact user input>"

**Valid modes:** <list all routing options>

**Example:** `/<skill> <example-keyword>`
```

---

## Choosing the right template

| My skill … | Template |
|---|---|
| Produces a scored table with ✅/⚠️/❌ | Assessment |
| Writes files, commits, or posts to external services | Workflow |
| Reads input and delegates to a sub-skill | Dispatcher |
| Does both assessment and action (e.g. review + fix) | Use Assessment template; add a Workflow block after the verdict |
