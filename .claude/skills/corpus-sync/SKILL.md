---
name: corpus-sync
description: >
  Sync completed phases into the phase corpus. Infers entries from prompt files, archives
  corpus, regenerates phase-corpus.jsonl, and flags exemplar candidates.
  Triggers: 'corpus-sync', 'sync corpus', 'update corpus', '/corpus-sync'.
argument-hint: "[--create] [--auto] [phase-id]"
allowed-tools: AskUserQuestion, Bash, Read, Glob, Grep, Edit, Write
---

# Corpus Sync

Finds completed phases not yet in the phase corpus, infers their entries from prompt files,
and regenerates the queryable JSONL. Invoke `/corpus-sync` whenever phases have been completed
since the corpus was last updated, or to verify the corpus is current.

## --create mode (bootstrap prereqs)

If `--create` is the first argument, read `.claude/skills/corpus-sync/corpus-sync-create.md`
and execute its Create 1–7 sequence. **Stop** at the end of that sequence — do not proceed to
Step 1 below. This mode is idempotent: safe to re-run on an already-initialised project.

---

If a specific phase ID is provided as an argument, only that phase is processed — useful for
adding a single phase without scanning the full registry.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `--create` | No | — | Bootstrap all prereqs (dirs, files, DuckDB check) and stop — does not sync |
| `phase-id` | No | _(all phases)_ | Restrict sync to a single phase ID (e.g. `27`) |
| `--auto` | No | _(interactive)_ | Skip confirmation prompts; auto-add clean phases, auto-skip flagged ones |

If no arguments are provided, all completed phases not yet in the corpus are scanned and
presented interactively. If `phase-id` is not found in `phases.yaml`, the skill stops with
an error (see Step 1 error handling).

---

Set this variable once so subsequent script calls are readable:

```bash
SCRIPTS=$(git rev-parse --show-toplevel)/.claude/skills/corpus-sync/scripts
```

---

## Step 1 — Identify gaps

```bash
uv run python "$SCRIPTS/find-candidates.py" $ARGUMENTS
```

Outputs a JSON array of `{id, name, directory}` objects for every completed phase
that has a prompt directory and is not yet in the corpus. Pass `$ARGUMENTS` so a
specific phase ID (if provided) filters the result. Parse the JSON array to get the
candidate list.

If the script exits non-zero, stop and report:

```
ERROR: find-candidates.py failed — check that prompts/phases.yaml exists and is valid YAML.
```

If a `phase-id` argument was provided but the script returns an empty array (the ID is not
in `phases.yaml` or is already in the corpus with `corpus_entry: true`), stop and report:

```
ERROR: Phase ID "<arg>" not found as a completed, uncatalogued phase in prompts/phases.yaml.
       Verify the ID and that the phase has status: completed and corpus_entry: false.
```

If no candidates are found (with no argument, meaning all phases are already catalogued),
output:

```
Corpus is current — nothing to add.
```

and stop.

Otherwise, list the candidates before proceeding:

```
Found N phase(s) missing from corpus: <id> "<name>", <id> "<name>", ...
```

---

## Step 1b — Check concern_score for each candidate

For each candidate phase ID, read its concern_score directly from `prompts/phases.yaml`:

```bash
uv run python -c "
import yaml, sys
phase_id = sys.argv[1]
data = yaml.safe_load(open('prompts/phases.yaml'))
phases = [p for p in data.get('phases', []) if p.get('id') == phase_id]
if phases:
    print(phases[0].get('concern_score', 'unknown'))
else:
    print('unknown')
" <phase_id>
```

For each candidate phase ID, check:

- `concern_score` — if ≥6, flag the phase as **high-concern**
- `concerns_file` — if the phases.yaml entry has a non-null `concerns_file`, read that file
  and check whether any entry has `category: contradiction`

Surface the result in the confirmation step (Step 3). **Do not skip a candidate
automatically** — the decision is the user's. But a phase with a `contradiction` concern
should carry a prominent warning: a contradictory prompt will mislead future inferences.

If `concern_score` is absent or `unknown` in phases.yaml, note it.

---

## Step 2 — Infer corpus entry for each candidate

For each candidate phase, verify its prompt directory and key files exist:

```bash
ls prompts/phase-<id>/
```

If the directory is absent, or if `00-pipeline.md` is not listed, skip this candidate and log:

```
phase <id> ("<name>"): skipped — prompt directory missing or 00-pipeline.md not found
```

Count these as "Skipped" in the Step 9 summary. Do not attempt inference without `00-pipeline.md`.

Read `00-pipeline.md` and every numbered step file (`01-*.md`, `02-*.md`, etc.) in full.

From these files, infer the following corpus fields using the source hierarchy below:

| Field | Primary source in prompt files |
|---|---|
| `phase_id` | Phase ID from phases.yaml (zero-padded string, e.g. `"26"`) |
| `name` | Phase name from phases.yaml |
| `type` | Infer from deliverable paths: if ≥70% of deliverable rows contain paths under `<source-dir>/`, `<test-dir>/`, or `infra/` → use the dominant type (`backend`, `testing`, `infra`). If no single category accounts for ≥70% of rows → `mixed`. For skill/harness files only (`.claude/`, `scripts/`, `prompts/`) → `harness`. For `docs/` only → `docs`. Labels in `00-pipeline.md` `issues:` block are a secondary signal to confirm the inferred type. |
| `directory` | Directory path from phases.yaml |
| `corpus_version` | Today's date as `"YYYY-MM-DD"` |
| `q1_goal` | Opening paragraph of the Context section — what the phase accomplished and why |
| `q2_current_state` | "Prior phases" or "Current state" bullets in Context |
| `q3_protected_scope` | "must not be modified" list in Context + "No changes to" in Constraints |
| `q4_deliverables` | "What to build" deliverables table — each file as `{path, action, description}` |
| `q4b_step_pattern` | `produces`/`requires` fields in `00-pipeline.md` — how steps were sequenced |
| `q5_api_shapes` | POST/GET request-response examples in step specs; existing route handlers if modified |
| `q6_processing_logic` | "Processing steps (implement in this order)" subsections |
| `q7_config_secrets` | "Environment variables" tables — list of `{name, source}` objects |
| `q8_tooling` | Constraints section — tool-specific bullets (e.g. OpenTofu, uv, model IDs) |
| `q9_security` | Constraints — Security bullet |
| `q9b_test_coverage` | Test file rows in deliverables table; specific assertion descriptions |
| `q10_verification` | Self-verification section — runnable shell commands with expected output |
| `q11_iteration_grouping` | Loop execution strategy — numbered list of iteration groups |
| `q12_docs` | Documentation deliverable rows in deliverables table |
| `review_scores` | Score each of the 10 dimensions below against the prompt quality |
| `review_total` | Sum of all `review_scores` values |

### review_scores dimensions

Score each dimension 0–2 based on how well the phase prompt expresses it:

| Key | Dimension | 2 = Strong | 1 = Partial | 0 = Missing |
|-----|-----------|------------|-------------|-------------|
| `C` | Context / Rationale | Clear why the phase exists and how it builds on prior work | Some context but gaps | No rationale |
| `S` | Scope Boundaries | Explicit "must NOT modify" file list | Vague scope limits | No scope limits |
| `D` | Deliverable Specification | Every output file in a table with path + action | Some files missing from table | No deliverable table |
| `B` | Behavioural Precision | Function signatures, HTTP shapes, typed fields | Present but incomplete | Prose only |
| `K` | Constraints | Security, tooling, compat rules explicitly stated | Scattered constraints | No constraints section |
| `V` | Verification Criteria | Runnable shell commands with expected output | Prose verification | No verification |
| `P` | Dependencies / Prerequisites | Prior phases named; read-before-starting files listed | Partial prereqs | No prereqs |
| `T` | Testability | Test files in deliverables table; assertions named | Tests mentioned in prose | No test deliverables |
| `Z` | Completion Signal | DONE gated on ≥4-item checklist | Unconditional DONE | No DONE signal |
| `CL` | Concerns Log | Concerns log block with all three categories | Partial concerns block | No concerns block |

---

## Step 3 — Present for confirmation

Check whether `--auto` was passed as an argument.

### If `--auto` is set

Do **not** call `AskUserQuestion`. For each candidate, apply this rule using the concern data from Step 1b:

| Condition | Decision |
|---|---|
| `concern_score < 6` **AND** no `category: contradiction` concern | **Auto-Add** |
| `concern_score ≥ 6` **OR** has `category: contradiction` concern | **Auto-Skip** |

Log each decision inline before proceeding:

```
phase <id> ("<name>"): auto-add  (concern_score=0, no contradictions)
phase <id> ("<name>"): auto-skip (concern_score=8 ≥ 6 threshold)
phase <id> ("<name>"): auto-skip (contradiction concern in concerns.md)
```

Auto-skipped phases are **not** appended to the corpus. Their `corpus_entry` flag remains `false`. They are counted separately in the Step 9 summary.

Proceed directly to Step 4 for each auto-added entry.

---

### If `--auto` is not set (interactive mode)

For each inferred entry, display a YAML preview and any concern flags:

```yaml
- phase_id: "<id>"
  name: "<name>"
  type: <type>
  directory: "<directory>"
  corpus_version: "<date>"
  q1_goal: >
    <inferred text>
  ...
  review_scores: {C: N, S: N, D: N, B: N, K: N, V: N, P: N, T: N, Z: N, CL: N}
  review_total: N
```

If a concern flag was found in Step 1b, display it prominently before the question:

```
⚠️  concern_score: 8 (≥6 threshold) — this phase had execution gaps; review concerns.md
    before adding as a corpus exemplar.
```

or:

```
🚫  CONTRADICTION concern found in prompts/phase-<id>/concerns.md — a contradictory
    prompt will mislead future inferences. Review before adding.
```

Then use `AskUserQuestion` to ask:

> "Add this entry for phase `<id>` ("<name>") to the corpus?"

Options (always available):
- **Add** — append entry as shown
- **Skip** — skip this phase; leave corpus_entry: false
- **Edit first** — pause; user will modify the preview manually before continuing

Additional option — **only include when a `contradiction` concern was found**:
- **Fix contradiction** — read concerns.md, propose corrections to affected corpus fields, apply before adding

If **Edit first**: stop and ask the user to paste back the corrected YAML before proceeding.

### Handling "Fix contradiction"

For each `category: contradiction` entry in the phase's concerns.md:

1. **Identify the affected corpus field** using this mapping:

   | Concern prompt section | Corpus field to update |
   |------------------------|----------------------|
   | Constraints / "No changes to" / "must not be modified" | `q3_protected_scope` |
   | Deliverable / "What to build" | `q4_deliverables` |
   | Processing steps / logic | `q6_processing_logic` |
   | Environment variables | `q7_config_secrets` |
   | Tooling | `q8_tooling` |
   | Security | `q9_security` |
   | Validation / Verify | `q10_verification` |
   | Other / unclear | ask the user |

2. **Propose a correction** by reading `"What I did"` from the concern entry. The correction should reflect actual execution, not the prompt as written. Format it as:

   ```
   Field: q3_protected_scope
   Current value: "No changes to infra/cloudbuild.tf, ..."
   Proposed fix:  Remove infra/cloudbuild.tf from the protected list.
                  Add note: "(infra/cloudbuild.tf was updated to replace an
                  orchestrator resource reference with a string literal — required
                  to avoid a tofu validate failure.)"
   ```

3. Ask the user to confirm each proposed correction with `AskUserQuestion`:

   > "Apply this correction to `q3_protected_scope`?"

   Options:
   - **Apply** — update the field as proposed
   - **Skip** — leave the field as inferred (contradiction remains)
   - **Edit** — user provides their own corrected value (ask them to paste it)

4. Apply all confirmed corrections to the in-memory entry, then proceed to Step 4 as **Add**.

If a concern entry's prompt section does not map clearly to a corpus field, present the full concern text and ask the user which field to update (or skip).

Process each candidate one at a time.

---

## Step 4 — Append confirmed entries to phase-corpus.yaml

For each confirmed entry, first verify it is not already in the corpus to prevent duplicates on re-run:

```bash
grep "phase_id: \"<id>\"" prompts/phase-corpus.yaml && echo "ALREADY_EXISTS" || echo "NOT_FOUND"
```

If `ALREADY_EXISTS`: skip this entry and log "phase `<id>` already in corpus — skipped". Do not append.

For each confirmed entry that is `NOT_FOUND`, append it to the `phases:` list in `prompts/phase-corpus.yaml`.

The file has a `# DEPRECATED — use phase-corpus.jsonl for all reads` header — leave that
header in place. The YAML is the **write source** for new entries; the JSONL is derived.

Append after the last existing entry in the `phases:` list (before any trailing newline).

After appending, update the top-level `corpus_version` field (near the top of the file)
to today's date. Use `Edit` to replace the existing value:

```yaml
corpus_version: "YYYY-MM-DD"
```

This field signals to consumers that the corpus has changed since they last read it.

---

## Step 5 — Update corpus_entry flag in phases.yaml

For each phase whose entry was appended, change its `corpus_entry` field in `phases.yaml`
from `false` to `true`.

Use `Edit` for each change, replacing the specific entry's `corpus_entry: false` line.
Never bulk-replace all occurrences — each edit must be scoped to the target phase's block.

---

## Step 6 — Regenerate JSONL

```bash
uv run python scripts/migrate-corpus.py
```

Expected output: `Wrote N entries to prompts/phase-corpus.jsonl`

If the script exits non-zero, stop and report the error.

---

## Step 7 — Verify alignment

```bash
YAML_COUNT=$(grep "^  - phase_id:" prompts/phase-corpus.yaml | wc -l | tr -d ' ')
JSONL_COUNT=$(wc -l < prompts/phase-corpus.jsonl | tr -d ' ')
echo "YAML entries: $YAML_COUNT  JSONL lines: $JSONL_COUNT"
[ "$YAML_COUNT" = "$JSONL_COUNT" ] && echo "OK — counts match" || echo "MISMATCH — investigate"
```

If counts don't match, stop and report.

---

## Step 8 — Exemplar quality comparison

Build the inputs from entries confirmed and added in Step 4:
- `NEW_IDS` — comma-separated phase_ids added this run, e.g. `"27,29"`
- `NEW_SCORES` — JSON array of `{phase_id, type, review_scores}` for each added entry

```bash
uv run python "$SCRIPTS/compare-exemplars.py" "$NEW_IDS" "$NEW_SCORES"
```

Outputs one line per new phase: which dimensions outscored the existing best for
that type, or "no dimensions outscored". This report is informational only — no
changes are made to the corpus based on it.

---

## Calibration

- **Strong:** `prompts/phase-corpus.jsonl` — the target output file; a well-formed corpus with ≥10 entries and no duplicate phase_ids. A sync run on an up-to-date corpus should produce "0 phases added | 0 errors."
- **Weak:** no committed weak example — adding a `mixed` phase and misclassifying its type (e.g. inferring `backend` when deliverables are 50%/50% across directories) is the most common error pattern. The 70% threshold rule in Step 1b prevents this.

## Standards

**review_scores dimensions** are scored against the 10 dimensions defined in `docs/skill-design-standards.md`. This skill is the **write path** for those scores — any rubric change there (dimension keys, 0–2 scale, descriptions) must be reflected in the corpus entry format here (the `review_scores` table in Step 2).

**Type inference rules and concern_score threshold** (concern_score ≥ 6 = flag as high-concern; type category requires ≥ 70% of deliverables in a single path group) are defined inline in Steps 1b and 2 of this skill. If these rules change, update them here AND in `docs/skill-design-standards.md`.

> TODO: If the type inference rules or concern_score threshold grow significantly beyond their current size (currently ~4 lines each), consider extracting them to `prompts/corpus-sync-rules.yaml` and reading that file in Step 2 rather than embedding them inline.

**Co-update dependencies:** `phase-sync` also reads `prompts/phases.yaml`; if the `phases.yaml` schema changes, both skills must be updated together. `corpus-query` is the read path for the corpus this skill writes — if the JSONL schema changes, update `corpus-query` alongside `corpus-sync`.

---

## Step 9 — Final report

Output a summary using this exact verdict format:

```
corpus-sync complete.
  Added: <N> entries (phase <id>, phase <id>, ...)
  Skipped: <N> (no directory, or user skipped)
  Auto-skipped (flagged): <F> (phase <id>: <reason>, ...)
  Updated: <K> entries (user applied Edit-first corrections)
  Errors: 0
  Corpus total: <N> entries
  corpus_version updated to <date>
  phase-corpus.jsonl regenerated successfully.

Final verdict: <N> phases added | <M> phases skipped | <F> auto-skipped (flagged) | <K> phases updated | 0 errors
```

The `Auto-skipped (flagged)` line and the `auto-skipped (flagged)` field in the verdict line are only shown when `--auto` was set. Omit them entirely in interactive mode.

The `Final verdict` line is the canonical single-line outcome. Always emit it on its own line, using this exact field order and the pipe-separated format shown.
