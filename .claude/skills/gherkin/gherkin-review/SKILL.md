---
name: gherkin-review
description: Audits an existing docs/ux/*.md Gherkin file against BDD quality standards, reports issues, and offers to patch the file. Sub-flow of the /gherkin skill.
disable-model-invocation: true
allowed-tools:
  - AskUserQuestion
  - ToolSearch
  - Read
  - Write
---

# Gherkin Scenario Reviewer

**First:** Read `.claude/skills/gherkin/bdd-standards.md` for the canonical quality rules, category definitions, and format. Then read `.claude/skills/gherkin/examples.md` for bad→good rewrites of the most common violations — use these as the basis for your fix suggestions. These are the criteria you audit against.

Audits an existing `docs/ux/*.md` Gherkin scenario file, reports quality issues and coverage gaps, then offers to apply fixes.

---

## Step 1 — Identify the file

If the invoker passed a file path, use it. Otherwise ask:

> Which Gherkin file would you like me to review? (e.g. `docs/ux/dynamic-board-config.md`)

Before reading, check the file exists:
```bash
test -f <path> && echo "OK" || echo "MISSING"
```
If missing: "File not found at `<path>`. Check the path and try again." Stop.

Then **Read** the file.

---

## Step 2 — Audit against BDD standards

Evaluate every scenario against each quality rule from `bdd-standards.md`. For each issue found, record:

- **Scenario title** (quote it)
- **Rule violated** (by number from `bdd-standards.md`)
- **What is wrong** (one concrete sentence)
- **Suggested fix** (rewritten line or new scenario)

Also check **coverage**:
- Is there at least one scenario in each applicable category (happy path, empty/loading, error, edge)?
- Are there failure modes or edge cases missing? Name each by explicit condition (e.g. 'missing Given clause when state setup is required', 'no error scenario for network failure').

---

## Step 3 — Report findings

Output a structured report:

```
## Gherkin review: <filename>

### Quality issues  (<N> found)

1. **"<scenario title>"** — Rule <N>: <what is wrong>
   Fix: <rewritten Given/When/Then line or replacement scenario>

2. ...

### Coverage gaps  (<N> found)

- Missing: <scenario description> (category: <category>)
- ...

### Summary
<1–2 sentences: overall quality and most important action>
```

If no issues are found in a section, write `None found.`

---

## Step 4 — Offer to patch

After the report, ask:

> Would you like me to apply these fixes to the file?
> - **Yes, apply all fixes** — rewrite the file with all issues resolved and gaps filled
> - **Yes, apply quality fixes only** — fix existing scenarios but do not add new ones
> - **No, report only** — leave the file unchanged

Then act on the user's choice:

- **Apply all / quality only:** Read the file again, make targeted edits using the suggested fixes, and Write the updated file. Confirm the path when done.
- **Report only:** Confirm the review is complete and remind the user the file was not changed.
