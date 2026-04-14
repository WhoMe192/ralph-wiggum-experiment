---
name: likec4-check
description: >
  Review LikeC4 .c4 files for structural validity and convention rule compliance. Use when:
  (1) validating a model after generation or editing, (2) running a quality gate before sharing,
  (3) diagnosing LikeC4 VS Code errors. Triggers: 'check c4 model', 'validate likec4',
  '/likec4-check'.
argument-hint: "<file-or-directory> [--docs] [--code]"
allowed-tools: Read, Edit, Write, Glob, Bash
---

# Review LikeC4 `.c4` files for structural validity and convention rule compliance

**Path**: $ARGUMENTS

Read `.claude/skills/likec4/dsl-reference.md` when executing Steps 3–8 — it defines all DSL
structural requirements (STRUCT-001–007) and convention rules (RULE-001–204).

## Inputs

| Input | Required | Default | Notes |
|-------|----------|---------|-------|
| `<file-or-directory>` | No | Ask user | Path to a `.c4` file or directory containing `.c4` files |
| `--docs` | No | off | Also check documentation references within the model for staleness |
| `--code` | No | off | Also cross-check element IDs and technology fields against source code |

If `<file-or-directory>` is omitted and `$ARGUMENTS` is empty, ask the user which file or
directory to review. Do not infer a default path.

**Idempotency:** this skill is read-only. Re-running on the same unchanged `.c4` files produces
identical output — no files are modified, no side effects occur.

## Step 0: Locate Files

If a file path is provided, use it directly.

If no argument is provided, ask the user which file or directory to review.

If a directory path is provided:

- Glob all `*.c4` files under that directory recursively.
- Boundary check: if ≥1 `.c4` file exists in the specified directory (or `docs/architecture/`
  when no path is given), proceed. If 0 `.c4` files are found, emit:
  ```
  No .c4 files found under <path>. Nothing to check.
  ```
  and stop.
- Also check the project root for `likec4.config.json` (RULE-004) and file naming
  patterns (RULE-105).

**Edge cases:**
- **Syntax error in a .c4 file:** report the specific file and line; do not abort the full check.
  Continue checking the remaining files and consolidate all errors in the final report.
- **Empty .c4 file:** emit `WARNING: <file> is empty — skipping` and continue to the next file.

## Step 1: Build Validation (if tooling available)

Before running any static pre-flight checks, verify Graphviz is available — LikeC4 requires
`dot` to render views. If missing, warn the user once at the top of the report:

```text
⚠ Graphviz not found — views will parse correctly but cannot be rendered.
  Install with: sudo apt-get install -y graphviz
  Add to .devcontainer/setup.sh to make this permanent for all developers.
```

Then attempt a real LikeC4 build:

```bash
npx likec4 gen model -o /tmp/likec4-check.ts
```

- **Exit code 0**: the workspace parses cleanly. Proceed to Step 2. Skip Step 3
  (the compiler has already verified STRUCT-001 to STRUCT-007 more reliably than
  static analysis can).
- **Non-zero exit / `npx` not found**: fall through to Step 3 (manual pre-flight).

If the build fails, surface the compiler output directly as authoritative STRUCT
violations and stop — do not continue to convention rules until structural errors are fixed.

## Step 2: Run Convention Tests (if present)

Check whether a Vitest test suite exists for the architecture model:

```bash
test -f vitest.config.ts && npm run test:arch 2>&1
```

- **Tests pass**: note this in the report header ("convention tests: all pass").
- **Tests fail**: include the failing assertions in the quality report as additional
  findings under their respective RULE numbers.
- **No `vitest.config.ts`**: skip silently and proceed to Step 3.

## Step 3: Structural Pre-flight

Before applying any convention rules, run the STRUCT-001 to STRUCT-007 checks defined
in `.claude/skills/likec4/dsl-reference.md`. If any blockers are found, report them and
stop — convention rules cannot be evaluated reliably until the DSL is structurally valid.

## Step 4: Convention Rules

If no blockers, apply all 13 convention rules (RULE-001 to RULE-204) as defined in
`.claude/skills/likec4/dsl-reference.md`.

## Step 5: Generate Report

Present the structured quality report grouped by severity:

```text
LikeC4 Quality Report — <path>
════════════════════════════════════
Verdict: Pass | Needs revision | Blocked

BLOCKER (fix before anything else)
  ✗ model.c4:12 — undeclared element kind 'component' (STRUCT-002)
    Evidence: "element component 'Orchestrator' {"
    Fix: add `element component` to _spec.c4 specification block

CRITICAL (must fix)
  ✗ orchestrator — missing metadata block (RULE-001)
    Evidence: "system orchestrator '<Project Name>' {"
    Fix: add `metadata { ref '<source-dir>/index.js' }` inside the element block
  ✗ orchestrator — vague description: 'handles requests' (RULE-003)
    Evidence: "description 'handles requests'"
    Fix: replace with a business-meaningful description, e.g. "Receives meeting transcripts,
    extracts action items via Claude, and creates <external-card>s"

HIGH (strongly recommended)
  ⚠ orchestrator — technology field missing on container (RULE-103)
    Evidence: "container orchestrator {"  (no technology field)
    Fix: add `technology 'Node.js 20, Express 4'`
  ⚠ orchestrator -> <external-api> — relationship label absent (RULE-104)
    Evidence: "orchestrator -> <external-api>"
    Fix: add a label, e.g. `orchestrator -> <external-api> 'Creates cards'`

MEDIUM (improve where possible)
  ~ <external-api> — tag not in UPPER_CASE (RULE-102)
    Evidence: "tag #external"
    Fix: rename to `#EXTERNAL`

LOW (minor polish)
  · No navigateTo links between related views (RULE-203)
    Evidence: (absent — no navigateTo declarations found)
    Fix: add `navigateTo <related-view>` inside relevant view blocks

Summary: 1 blocker, 2 critical, 2 high, 1 medium, 1 low — 7 issues total
════════════════════════════════════

Would you like to work through these interactively? (yes / no)
```

**Verdict selection rules:**

| Verdict | Condition |
|---------|-----------|
| `Blocked` | ≥1 BLOCKER finding (structural errors prevent convention checking) |
| `Needs revision` | 0 blockers AND ≥1 CRITICAL or HIGH finding |
| `Pass` | 0 blockers, 0 critical, 0 high (MEDIUM and LOW findings may still exist) |

## Step 6: Markdown Export (opt-in)

After the report, offer to save it as a markdown file:

```text
Save report to docs/architecture/likec4-quality-report.md? (yes / no)
```

## Step 7: Offer Coaching

If the user accepts interactive coaching, work Blocker → Critical → Low, one issue at a time:

- Show the problematic element or relationship
- Explain why it violates the rule
- Propose a specific fix
- Apply edits with the Edit tool only after explicit user confirmation

## Step 8: Sharing Guidance

Display the "Sharing Your Model" section from `.claude/skills/likec4/dsl-reference.md` once per
session — after the report (if the user declines coaching) or after coaching completes.

## Calibration

- **Strong:** no LikeC4 model files committed yet — update when first `.c4` file is added to `docs/architecture/`. A strong example is a model that passes Steps 1–4 with 0 blockers and ≤2 medium findings.
- **Weak:** no committed weak artefact yet — update when a `.c4` file with a confirmed STRUCT violation (e.g. undeclared element kind) is documented.

See `docs/skill-calibration-manifest.md` §BDD and diagram skills.

## References

- **DSL rules and convention rules**: `.claude/skills/likec4/dsl-reference.md`
- **Model generation skill**: `.claude/skills/likec4/likec4-model/SKILL.md`
- **LikeC4 DSL reference**: <https://likec4.dev/dsl/>
- **LikeC4 validation guide**: <https://likec4.dev/guides/validate-your-model/>
