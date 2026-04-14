# Ralph-loop PROMPT examples

Reference calibration for writing ralph-loop PROMPT files. Each section below contrasts a
weak phrasing against a strong one and explains why the strong version makes the loop
converge faster.

All examples use placeholders — `<service>`, `<entity>`, `<external-api>`, `<source-dir>`,
`<test-dir>` — rather than domain-specific terms. Replace them with your project's actual
identifiers when authoring a real phase.

---

## 1. Goal statement

### Weak

> Add a new endpoint so we can also process `<entity-B>` records.

Issues: no protected scope, no success criterion, no mention of existing code that must not
be touched.

### Strong

> Add a new `POST /<source-dir>/<verb>-b` endpoint to the existing `<service>` that accepts
> `<entity-B>` payloads, persists them to `<datastore>`, and returns a normalised ID. The
> existing `POST /<verb>-a` route and its storage layer must not be modified — they remain
> the sole path for `<entity-A>` until `<entity-B>` is validated in UAT. Done means a
> request/response integration test is green *and* the deliverables table is satisfied.

Why: scope is bounded (new route only), protected scope is explicit, done-criterion is
objective.

---

## 2. Constraints

### Weak

> Don't break anything that already works.

Issues: unverifiable, doesn't tell the loop which files to leave alone.

### Strong

> The following must remain untouched:
>
> - `<source-dir>/routes/<verb>-a.ts` — existing handler
> - `<source-dir>/lib/<external-api>-client.ts` — shared client, version-pinned
> - Any file under `infra/` — infrastructure is out of scope for this phase
>
> New code goes in `<source-dir>/routes/<verb>-b.ts` and a new module
> `<source-dir>/lib/<entity-b>-normaliser.ts`.

Why: protected list is enumerable, and the intended write locations are stated up front so
the loop doesn't scatter changes.

---

## 3. Deliverables table

### Weak

| Action | File |
| --- | --- |
| Add endpoint | backend |
| Write tests | test file |

Issues: files unspecified, no create-vs-update distinction, no description.

### Strong

| File | Action | Notes |
| --- | --- | --- |
| `<source-dir>/routes/<verb>-b.ts` | Create | Request handler, schema validation via `<schema-lib>` |
| `<source-dir>/lib/<entity-b>-normaliser.ts` | Create | Pure function, exports `normalise(input): Normalised` |
| `<source-dir>/index.ts` | Update | Register the new route on the existing router |
| `<test-dir>/<verb>-b.test.ts` | Create | Happy path + 3 error cases (invalid schema, duplicate ID, downstream 5xx) |
| `docs/api.md` | Update | Add `<verb>-b` section with request/response examples |

Why: each row is a single file, has an unambiguous action, and the Notes column gives the
loop just enough context to pick the right library / pattern without improvising.

---

## 4. API / data-schema detail

### Weak

> The endpoint accepts a JSON body with the relevant fields.

Issues: "relevant" is subjective; the loop will invent fields.

### Strong

> **Request body (application/json):**
>
> ```json
> {
>   "externalId": "<string, 1-64 chars>",
>   "label": "<string, optional>",
>   "attributes": [
>     { "key": "<string>", "value": "<string>" }
>   ]
> }
> ```
>
> **Response 201:**
>
> ```json
> {
>   "id": "<uuid>",
>   "externalId": "<string>",
>   "createdAt": "<iso-8601>"
> }
> ```
>
> **Error responses:** `400` on schema failure, `409` on duplicate `externalId`, `502`
> when the downstream `<external-api>` returns 5xx.

Why: schemas pinned means the test file has a single valid shape to target; error codes are
named so the test cases can be enumerated.

---

## 5. Verification commands

### Weak

> Run the tests.

Issues: which tests? Where? What if something else regresses?

### Strong

Per-step verification:

```bash
# Structural checks
<type-check-command>
<lint-command> <source-dir>/routes/<verb>-b.ts <source-dir>/lib/<entity-b>-normaliser.ts

# Focused test
<test-runner> <test-dir>/<verb>-b.test.ts

# Regression
<project-defined full-suite command>
```

On success, append a line to `prompts/phase-NN/progress.md` of the form
`STEP <id>: DONE <short-summary>` and commit only the files listed in the deliverables
table.

Why: separates structural (fast) from behavioural (slower) checks, names a progress
artefact, and forces the commit scope to match the plan.

---

## 6. Escape hatch

### Weak

(section omitted)

Issues: the loop has no sanctioned way to stop when it is genuinely stuck, so it either
thrashes or declares false completion.

### Strong

> **Escape hatch.** If after three consecutive per-step failures the root cause is one of
> the following, stop the loop and surface the block to the user:
>
> 1. A protected file would need to change (see Constraints section)
> 2. A required external service or credential is unavailable in this environment
> 3. The deliverables table is internally inconsistent with the API schema
>
> When stopping, write a single-line reason to `prompts/phase-NN/blocked.md` in the form
> `BLOCKED: <reason> - <step-id>` and exit non-zero.

Why: gives the loop a specified termination condition for unrecoverable states, so a
human can pick up quickly.

---

## 7. Phases to model on

Well-structured phases have, in order:

1. A one-sentence goal
2. A protected-scope list
3. A deliverables table (one row per file, with action + notes)
4. API / data-schema detail for any interface change
5. Per-step verification command block
6. An escape-hatch section

A phase prompt that omits any of these is a candidate for the `ralph-prompt-review` skill
before running the loop against it.
