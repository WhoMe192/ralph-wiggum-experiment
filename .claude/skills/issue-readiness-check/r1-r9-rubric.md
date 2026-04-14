# R1–R9 Issue Readiness Rubric

Shared rubric used by `issue-readiness-check` and `issue-refine`. When this file changes,
both skills are automatically updated on next invocation.

---

## Label modifiers

| Label present | Modifier |
|---|---|
| `harness` | R5 uses shell test script wording (not <test-runner>/<e2e-runner>) |
| `bug` | R2 requires a reproduction path, not just a solution description |
| `documentation` | R4/R5 relaxed — docs-only issues need a review checklist, not a test file |

---

## Tier 1 rubric (all required)

Evaluate each criterion as **✅ Strong**, **⚠️ Partial**, or **❌ Missing**.

---

**R1 — Problem statement**

> Is it clear in ≤2 sentences what is broken or missing?

- ✅ Strong: states the specific broken behaviour, missing feature, or gap — not a task name
- ⚠️ Partial: problem implied or described vaguely ("things could be improved")
- ❌ Missing: only a solution described with no problem context

---

**R2 — Solution approach**

> Is the proposed approach specific enough that two engineers would implement it the same way?

- ✅ Strong: names the mechanism, algorithm, or design (e.g. "add pagination with Prev/Next buttons, PAGE_SIZE=10, reset on selection change")
- ⚠️ Partial: directional but open-ended (e.g. "add pagination" with no detail)
- ❌ Missing: no solution described, or only "fix it"

`bug` modifier: also requires a reproduction path or failing condition.

---

**R3 — Affected area**

> Is there at least a module or service identified? File paths are ideal.

- ✅ Strong: specific file paths (e.g. `<source-dir>/index.js`, `.claude/skills/ralph-loop/`)
- ⚠️ Partial: module or service name without file paths (e.g. "the admin prompts view", "stop-hook.sh")
- ❌ Missing: no indication of where in the codebase the change lives

---

**R4 — Acceptance criteria**

> Is there at least one concrete, verifiable "done when..." statement?

- ✅ Strong: a checkboxed list or explicit "Done when X shows Y and test Z passes"
- ⚠️ Partial: acceptance implied in the problem description but not stated as a criterion
- ❌ Missing: no verifiable completion condition

`documentation` modifier: a review checklist or "section updated" condition counts as ✅.

---

**R5 — Test coverage**

> Is it clear what type of test covers this, and what behaviour it asserts?

Standard issues:
- ✅ Strong: names the test file (`<test-dir>/foo.test.js`) and specific assertions
- ⚠️ Partial: mentions "add <test-runner> test" or "add <e2e-runner> test" without specifics
- ❌ Missing: no mention of testing

`harness` modifier — expected answer is a shell test script:
- ✅ Strong: names a shell script (e.g. `scripts/test-issue-readiness.sh`) and what it asserts
- ⚠️ Partial: mentions "verify manually" or "run the skill and check"
- ❌ Missing: no mention of how to verify the harness change

`documentation` modifier: R5 is not required — skip.

---

## Tier 2 rubric (conditional — only flag if condition is true AND criterion is missing)

**R6 — API shapes**

Condition: issue body mentions a new route, endpoint, HTTP method, or API response change.

If condition true and missing:
> What does the request look like and what does the response look like? Include error cases.

**R7 — Processing algorithm**

Condition: issue describes non-trivial logic (matching, deduplication, extraction, state
machine, multi-step transformation) — not simple CRUD.

If condition true and missing:
> What are the processing steps in order? Are there specific rules, algorithms, or edge cases?

**R8 — Out-of-scope declaration**

Condition: issue overlaps in subject matter with another currently open issue (check issue
titles and bodies for shared keywords or file references).

If condition true and missing:
> What does this issue explicitly NOT cover? Listing what's out of scope helps scope the phase.

**R9 — Manual prerequisites**

Condition: issue body contains any of: "GCP Console", "OAuth", "IAM", "one-time", "manually",
"browser flow", "third-party app".

If condition true and missing:
> Are there any steps that cannot be automated — e.g. OAuth flows, GCP Console config, one-time
> IAM grants? List them so the phase README can document them for the operator.