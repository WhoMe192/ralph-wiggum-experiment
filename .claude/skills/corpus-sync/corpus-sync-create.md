# corpus-sync — `--create` bootstrap mode

This file documents the bootstrap sequence for `/corpus-sync --create`. The parent skill
(`SKILL.md`) delegates to this file when `--create` is the first argument and stops after
it completes. This mode is idempotent: safe to re-run on an already-initialised project.

## Create 1 — Directory structure

```bash
mkdir -p prompts/completed
```

## Create 2 — phases.yaml

```bash
test -f prompts/phases.yaml && echo "EXISTS" || echo "MISSING"
```

If `MISSING`, write `prompts/phases.yaml`:

```yaml
phases: []
```

Report: `created prompts/phases.yaml` or `prompts/phases.yaml already exists — skipped`.

## Create 3 — phase-corpus.yaml

```bash
test -f prompts/phase-corpus.yaml && echo "EXISTS" || echo "MISSING"
```

If `MISSING`, write `prompts/phase-corpus.yaml`:

```yaml
# DEPRECATED — use phase-corpus.jsonl for all reads
corpus_version: "YYYY-MM-DD"
phases: []
```

Replace `YYYY-MM-DD` with today's date.

Report: `created prompts/phase-corpus.yaml` or `prompts/phase-corpus.yaml already exists — skipped`.

## Create 4 — phase-corpus.jsonl

```bash
test -f prompts/phase-corpus.jsonl && echo "EXISTS" || echo "MISSING"
```

If `MISSING`, create an empty file:

```bash
touch prompts/phase-corpus.jsonl
```

Report: `created prompts/phase-corpus.jsonl (empty)` or `prompts/phase-corpus.jsonl already exists — skipped`.

## Create 5 — DuckDB availability check

```bash
uv run python -c "import duckdb; print('duckdb', duckdb.__version__)" 2>&1
```

- If the command succeeds and prints a version → ✅ DuckDB available.
- If the import fails with `ModuleNotFoundError` → check whether `pyproject.toml` exists:

  ```bash
  test -f pyproject.toml && echo "EXISTS" || echo "MISSING"
  ```

  - If `pyproject.toml` **exists** but lacks duckdb: report
    `⛔ BLOCKED: add duckdb>=1.5.1 to the [project.dependencies] section in pyproject.toml,
     then run uv sync`.
  - If `pyproject.toml` **does not exist**: report
    `⛔ BLOCKED: no pyproject.toml found. Create one with duckdb>=1.5.1 in [project.dependencies]
     and run uv sync to install.`

## Create 6 — Script availability check

Check that the two helper scripts this skill requires are in place:

```bash
test -f .claude/skills/corpus-sync/scripts/find-candidates.py && echo "OK" || echo "MISSING"
test -f scripts/migrate-corpus.py && echo "OK" || echo "MISSING"
```

If either is `MISSING`, report:
`⛔ BLOCKED: <path> not found. This script is required for corpus-sync to run.
 Recreate it from this skill's template or restore from git history.`

## Create 7 — Summary

Output a table:

```text
corpus-sync bootstrap complete.

  prompts/phases.yaml          <created | already existed>
  prompts/phase-corpus.yaml    <created | already existed>
  prompts/phase-corpus.jsonl   <created | already existed>
  prompts/completed/           <created | already existed>
  DuckDB                       <✅ available vX.Y.Z | ⛔ BLOCKED — see above>
  find-candidates.py           <✅ found | ⛔ MISSING>
  migrate-corpus.py            <✅ found | ⛔ MISSING>
```

If any ⛔ BLOCKED items remain, end with:
`Bootstrap incomplete — resolve blocked items before running /corpus-sync.`

Otherwise:
`Bootstrap complete — run /corpus-sync to populate the corpus.`

**Stop here. Do not proceed to Step 1 of the parent skill.**
