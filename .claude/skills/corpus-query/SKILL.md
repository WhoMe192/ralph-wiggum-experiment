---
name: corpus-query
description: >
  Query phase-corpus.jsonl via DuckDB; return top N exemplars by type. Invoke via Agent
  (not Skill) to keep corpus out of parent context. Not a direct user skill.
  Triggers: 'query corpus for exemplars', 'get top 2 backend phases from corpus'.
allowed-tools: Bash, Read
---

# Corpus Query

Queries `prompts/phase-corpus.jsonl` using DuckDB and returns the top matching records.
This skill runs as a subagent — all corpus data stays in this isolated context.
The parent receives only the filtered result rows.

**Design rationale:** DuckDB is used for in-process SQL over JSONL without requiring a server.
It avoids standing up a database process and supports rich SQL predicates (including `list_contains`)
directly on newline-delimited JSON files. See `docs/skill-design-standards.md` for the relationship
map between corpus-query, corpus-sync, and phase-sync.

---

## Inputs

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `type` | Required | — | Phase type(s) to filter on (e.g. `harness`, `backend`, `frontend`). For mixed-type phases stored as a JSON array, use the `list_contains` predicate. |
| `limit` | Optional | `2` | Maximum number of records to return. |
| `min_review_total` | Optional | — | If set, only return records where `review_total` is at or above this value. |
| `phase_id` | Optional | — | Filter to a specific phase by ID. |

**Missing required `type`:** if the parent prompt does not specify a type, report: `ERROR: required parameter 'type' not provided — specify a phase type (e.g. harness, backend, frontend) in the Agent invocation prompt.` and stop.

**Idempotency:** repeated identical queries return identical results for the same JSONL state. This skill performs no writes and has no side effects — re-running on unchanged input produces the same output.

---

## How to invoke (from a parent skill)

Use the `Agent` tool with `subagent_type: general-purpose`. Pass a prompt that specifies:
- The phase type(s) to match (e.g. `harness`, `backend`, `frontend`)
- The number of records to return (default: 2)
- Any additional filter (e.g. minimum review_total)

Example invocation from ralph-prompt-auto:

```
Agent tool:
  subagent_type: general-purpose
  description: "query corpus for harness exemplars"
  prompt: |
    Follow the instructions in .claude/skills/corpus-query/SKILL.md.
    Query: return the top 2 entries where type = 'harness', ordered by review_total DESC.
```

---

## How to execute a query

### Step 1 — Confirm JSONL exists

```bash
test -f prompts/phase-corpus.jsonl && echo "OK" || echo "MISSING"
```

If missing, report: "phase-corpus.jsonl not found — run phase 25 migration step first."

### Step 2 — Run the DuckDB query

Use `uv run python` to execute the query:

```bash
uv run python -c "
import duckdb, json

result = duckdb.sql(
    \"SELECT * FROM read_json('prompts/phase-corpus.jsonl') \"
    \"WHERE type = 'REPLACE_TYPE' \"
    \"ORDER BY review_total DESC LIMIT REPLACE_N\"
).fetchall()

cols = ['phase_id','name','type','directory','corpus_version','review_scores',
        'review_total','q1_goal','q2_current_state','q3_protected_scope',
        'q4_deliverables','q4b_step_pattern','q5_api_shapes','q6_processing_logic',
        'q7_config_secrets','q8_tooling','q9_security','q9b_test_coverage',
        'q10_verification','q11_iteration_grouping','q12_docs']

for row in result:
    print(json.dumps(dict(zip(cols, row)), ensure_ascii=False))
"
```

Replace `REPLACE_TYPE` with the queried type and `REPLACE_N` with the record limit.

### Step 3 — For mixed-type phases

When a phase has multiple types (stored as a JSON array), use the same `uv run python` invocation as Step 2, substituting the WHERE predicate:

```sql
WHERE list_contains(type, 'frontend')
```

All other code (imports, column list, JSON output loop) is identical to Step 2.

---

## Standard query patterns

| Use case | SQL predicate |
|---|---|
| Single type | `WHERE type = 'backend'` |
| Mixed-type phase (any match) | `WHERE list_contains(type, 'frontend')` |
| Top N by score | `ORDER BY review_total DESC LIMIT 2` |
| Lowest-scoring (for review) | `ORDER BY review_total ASC LIMIT 5` |
| Specific phase | `WHERE phase_id = '12'` |

---

## Standards and co-update partners

This skill depends on the following:
- **corpus-sync** — populates `prompts/phase-corpus.jsonl`; if corpus-sync has not been run after a phase completes, this skill may return stale or missing records.
- **phase-sync** — keeps `prompts/phases.yaml` and `prompts/phase-runs.yaml` consistent; phase metadata queried here must match what phase-sync maintains.

**Co-update trigger:** If the corpus schema changes (new columns, renamed fields), update the column list in Step 2 and notify the maintainers of corpus-sync and phase-sync.

## Output format

Return the matching JSON objects — one per line, nothing else.
Do not add preamble, explanation, or trailing text.
The parent skill will parse each line as a JSON object.

**Verdict** (always emit exactly one of these as the final line, prefixed with `# verdict:`):

- `success (≥1 record)` — query completed and at least one record was returned
- `failure (0 rows)` — query completed but returned no records matching the filter
- `error (file missing)` — `phase-corpus.jsonl` does not exist

**Success output example:**

```json
{"phase_id":"22","name":"Telemetry Enrichment","type":"harness","review_total":17,...}
{"phase_id":"18","name":"Harness Reliability","type":"harness","review_total":16,...}
# verdict: success (≥1 record)
```

**Failure output example (0 rows):**

```text
# evidence: query WHERE type = 'nonexistent' ORDER BY review_total DESC LIMIT 2 returned 0 rows
# verdict: failure (0 rows)
```

**Failure output example (file missing):**

```text
# evidence: test -f prompts/phase-corpus.jsonl returned non-zero; file does not exist
# verdict: error (file missing)
```

## Success criteria

This skill succeeds when: the DuckDB query completes without error and at least one matching record is returned as a JSON line.

This skill fails if: `phase-corpus.jsonl` is missing (report and stop), the query returns 0 rows (report "No matching records for the requested filter"), or the DuckDB Python invocation throws an exception.

## Calibration

- **Strong:** `prompts/phase-corpus.jsonl` — the target input file; a well-formed corpus with ≥10 phase entries. A query with `type = 'harness'` should return top 2 records as one JSON object per line with no headers or row counts.
- **Weak:** no committed weak corpus example — `prompts/phase-corpus.jsonl` queried after a new phase completes but before `corpus-sync` is run produces stale results. Update when a confirmed-stale corpus run is documented.
