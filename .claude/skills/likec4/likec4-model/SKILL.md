---
name: likec4-model
description: >
  Generate or update a LikeC4 .c4 architecture model from project documents and/or source code.
  Detects drift between documented intent and actual implementation. Use when: (1) creating a new
  .c4 diagram for a project, (2) updating an existing .c4 diagram to reflect current code,
  (3) understanding what docs say vs what code does. Triggers: 'generate c4 model',
  'update c4 diagram', 'create architecture diagram', '/likec4-model'.
argument-hint: "<project-directory> [--docs-only | --code-only]"
allowed-tools: Read, Edit, Write, Glob, Bash
---

# Generate or update a LikeC4 `.c4` architecture model

**Path**: $ARGUMENTS

Read `.claude/skills/likec4/dsl-reference.md` before generating any `.c4` output — it defines
all DSL structural requirements (STRUCT-001–007), convention rules (RULE-001–204), and reserved
keywords that generated files must satisfy.

---

## Inputs

| Input | Required | Default | Notes |
|-------|----------|---------|-------|
| `<project-directory>` | Yes | Ask user | Root directory of the project to model |
| `--docs-only` | No | off | Scan documentation sources only; skip code scan and drift detection |
| `--code-only` | No | off | Scan source code only; skip documentation scan and drift detection |

If `<project-directory>` is absent, ask before proceeding. Do not infer a default path.

---

## Step 0: Resolve Input

Parse `$ARGUMENTS`:

- Extract the project directory path (required — ask if missing)
- Detect mode flag: `--docs-only`, `--code-only`, or neither (default: both)
- Confirm to the user before proceeding:

```text
Analysing <path> — mode: [docs+code | docs-only | code-only]
```

---

## Step 1: Source Discovery

Scan the project directory. Report a summary of what was found before extracting anything:
"Found N doc files, M code files, K existing .c4 files."

**Skip documentation scan if `--code-only`.**

Documentation sources to glob and read:

- `README.md`, `docs/**/*.md`, `*.md` at root
- `docs/architecture.md`, `docs/adr/`, `docs/<datastore>-data-model.md`
- `orchestrator/package.json`, `infra/*.tf`
- Existing `.c4` files — if ≥1 `.c4` file is found anywhere under the project directory,
  the model will be **updated**, not replaced

**Skip code scan if `--docs-only`.**

Code sources to glob and read:

- Entry points: `<source-dir>/index.js`, `orchestrator/server.js` or similar
- Route definitions: files matching `*router*`, `*routes*`, `*handler*`
- Dependency manifests: `orchestrator/package.json`
- Infrastructure: `Dockerfile`, `infra/*.tf`, `cloudbuild.yaml`
- Config: `*.env.example`, `infra/variables.tf`
- Outbound HTTP calls: grep for `fetch(`, `axios.`, `https://` — these reveal external integrations

---

## Step 2: Extraction

Build two views from the sources found. Skip the view not applicable to the selected mode.

**Doc view** — extract from documentation:

- System name and one-line purpose
- Named actors, users, or personas
- Named services, subsystems, or bounded contexts
- Described APIs and contracts (endpoints, protocols)
- Mentioned technology choices
- External systems referenced by name (<external-service>, Claude API, Google Cloud)
- Described data flows and relationships between components

**Code view** — extract from source:

- Actual service name (from `package.json` `name`)
- Actual technology stack (Node.js version, frameworks from package.json)
- Actual API surface (HTTP verbs and route paths found in router/handler files)
- Actual outbound integrations (HTTP calls, external API calls)
- External services inferred from config or env vars
  (e.g. `<EXT_API_KEY>` → <external-service>, `ANTHROPIC_API_KEY` → Claude API)
- Infrastructure topology (Cloud Run, GCS, <datastore>, Artifact Registry)

---

## Step 3: Drift Detection

**Skip this step entirely if `--docs-only` or `--code-only`.**

Compare the doc view against the code view. Classify each element and relationship:

| Category | Meaning |
| --- | --- |
| `ALIGNED` | Both sources agree on existence, technology, and relationships |
| `DOCS_ONLY` | Described in docs — no corresponding code found; possibly planned, deprecated, or doc is stale |
| `CODE_ONLY` | Found in code — not described in docs; shadow architecture |
| `TECH_MISMATCH` | Docs name technology X, code evidence shows technology Y |
| `REL_MISMATCH` | Docs describe relationship A→B, code shows a different or absent call pattern |

Present a **Drift Summary** and wait for confirmation before writing any files:

```text
Drift Summary — <project-directory>
════════════════════════════════════

ALIGNED
  ✓ <element> — <brief description of agreement>

DOCS_ONLY (in docs, not found in code)
  ⚠ <element> — described in <source>, no code found

CODE_ONLY (in code, not documented)
  ⚠ <element> — found in <file:line>, not in docs

TECH_MISMATCH
  ⚠ <element> — docs say '<X>', code shows '<Y>'

REL_MISMATCH
  ⚠ <source> → <target> — docs say '<label>', code shows '<actual>'

Proceed to resolve drift items? (yes / adjust / cancel)
```

---

## Step 3b: Drift Resolution

**Skip this step if there are no drift items, or if `--docs-only` or `--code-only`.**

After the user confirms proceeding, present a resolution table for every non-ALIGNED item.
Suggest a default action and explain the reasoning. Wait for the user to confirm or override
before making any changes.

```text
Drift Resolution Plan
─────────────────────────────────────────────────────────────────────────────
For each item choose an action:
  docs  — update the documentation to reflect what the code actually does
  code  — update the code to match what the documentation describes
  model — tag in the .c4 model only (#DRIFT_*); no doc or code changes now

# Item                  Category        Suggested  Reason
  <id>                  CODE_ONLY       docs       code exists; docs are stale or incomplete
  <id>                  DOCS_ONLY       docs       verify planned vs deprecated; update or remove
  <id>                  TECH_MISMATCH   docs       code is the authoritative source of technology
  <id>                  REL_MISMATCH    docs       actual call pattern differs from description

Reply to confirm the plan, or override any action before I proceed.
─────────────────────────────────────────────────────────────────────────────
```

### Suggested defaults by category

| Category | Default suggestion | Rationale |
| --- | --- | --- |
| `CODE_ONLY` | `docs` | Code exists and works; documentation is missing or stale |
| `DOCS_ONLY` | ask user | Could be planned (code to write) or deprecated (doc to remove) |
| `TECH_MISMATCH` | `docs` | Running code is the ground truth for technology choices |
| `REL_MISMATCH` | `docs` | Actual call patterns in code override described relationships |

---

## Step 4: Model Generation

Apply all DSL rules from `.claude/skills/likec4/dsl-reference.md` throughout. Do not write `.c4`
files until Step 3b resolutions are complete (or drift detection was skipped).

When tagging elements in the model:

- Apply `#DRIFT_*` tags **only** to items whose Step 3b action was `model` (unresolved)
- Do not tag items whose drift was resolved via `docs` or `code` actions in Step 3b

### Determine output location

- If ≥1 `.c4` files exist anywhere under the project directory: use their directory
- If 0 `.c4` files exist: use `docs/architecture/` (create if absent)

### If 0 `.c4` files exist — create from scratch

**1. `_spec.c4`**

Check whether a `_spec.c4` already exists anywhere in the workspace:

- If yes: read it and reuse declared kinds and tags; only add tags that are genuinely new
- If no: scaffold `_spec.c4` with the standard kinds

Always declare the drift tags if drift detection ran and found issues:

```c4
specification {
  element actor
  element system
  element container
  element component

  // drift tags — remove once all issues are resolved
  tag DRIFT_DOCS_ONLY
  tag DRIFT_CODE_ONLY
  tag DRIFT_TECH_MISMATCH
  tag DRIFT_REL_MISMATCH
}
```

One `_spec.c4` per project directory — never duplicate kind or tag declarations (STRUCT-004).

**2. `model.c4`**

```c4
model {

  // elements here, following all RULE-001–104 requirements

}
```

For every element:

- ID: kebab-case derived from service/component name (RULE-002)
- Title: human-readable name in single quotes (RULE-101)
- Description: business-meaningful, not vague (RULE-003)
- `technology`: required on all containers and components; use specific values from code
  (`'Node.js, Express'` not `'backend'`) (RULE-103)
- `metadata`: at least one source ref — use file path (`ref '<source-dir>/index.js'`)
  if no URL is available (RULE-001)
- Drift tags: `#DRIFT_DOCS_ONLY`, `#DRIFT_CODE_ONLY`, etc. as appropriate (RULE-102: `#UPPER_CASE`)

For every relationship:

- Label describes the business interaction, not just the protocol (RULE-104)
- `technology` field for the transport or protocol

### If ≥1 `.c4` files exist — update in place

1. Read all existing `.c4` files
2. For each existing element:
   - Preserve the element ID and existing metadata keys
   - Update `technology`, `description`, or `metadata` only where evidence justifies the change
   - Add a `# updated: <YYYY-MM-DD>` comment above changed blocks
3. Add new elements discovered from this analysis
4. Add or correct relationships based on code evidence
5. Add drift tags to elements where applicable

---

## Step 4b: View Generation

Generate views for C4 levels 1–3 and a deployment diagram where infrastructure files were found.

| C4 Level | View type | When to generate |
| --- | --- | --- |
| 1 | System Context | Always — the default entry point |
| 2 | Container | Always — one per primary system |
| 3 | Component | Conditional — only when `component` elements exist inside a container |
| — | Deployment | Conditional — only when infrastructure files were found (`.tf`, `Dockerfile`) |

After writing `model.c4`, always create or update `view.c4` in the same output directory.
LikeC4 requires `dot` (Graphviz) to render views. If `dot` is not found, warn:

```text
⚠ Graphviz not found — views will be written but cannot be rendered until graphviz is installed.
  Install with: sudo apt-get install -y graphviz
  Add to .devcontainer/setup.sh to make this permanent.
```

### Views to generate

**1. System Context (C4 Level 1)**:

```c4
views {

  view index {
    title 'System Context'
    include *
  }

}
```

**2. Container view (C4 Level 2)**:

```c4
  view <system-id>_containers of <system-id> {
    title '<System Name> — Containers'
    include *
  }
```

**3. Component view (C4 Level 3)** — conditional; only if containers have component children:

```c4
  view <container-id>_components of <container-id> {
    title '<Container Name> — Components'
    include *
  }
```

**4. Deployment view** — conditional; only if infrastructure files were found:

```c4
  view deployment {
    title 'Deployment — GCP Cloud Run'
    include *
  }
```

---

## Step 5: Output Summary

After writing files, display:

```text
Model written
─────────────────────────────────────────
Files written:
  <path>/_spec.c4    (new | updated)
  <path>/model.c4    (new | updated)
  <path>/view.c4     (new | updated)

Views generated:
  index                    — system landscape (all elements)
  <system-id>_containers   — container drill-down
  deployment               — GCP Cloud Run topology  [if infra found]

Elements: N total (X aligned, Y resolved, Z drift items remaining)
Relationships: N

Run /likec4-check <path> to validate the generated model.
─────────────────────────────────────────
```

---

## Step 6: Compliance Check Prompt

```text
Would you like me to run /likec4-check on the generated model now? (yes / no)
```

If yes: run the check sub-skill on the output directory. Fix any violations before finishing.

Display the "Sharing Your Model" section from `.claude/skills/likec4/dsl-reference.md` after
the check completes (or after declining the check).

---

## Calibration

No LikeC4 model files are committed to this repository yet. Update this section when the first
`.c4` model file is committed to `docs/architecture/`.

| Quality | Reference | Why |
|---------|-----------|-----|
| Strong example | no committed artefact yet — update when first .c4 model file is committed | |
| Weak example | no committed artefact yet — update when first .c4 model file is committed | |

---

## References

- **DSL rules and convention rules**: `.claude/skills/likec4/dsl-reference.md`
- **Check sub-skill**: `.claude/skills/likec4/likec4-check/SKILL.md`
- **LikeC4 DSL reference**: <https://likec4.dev/dsl/>
