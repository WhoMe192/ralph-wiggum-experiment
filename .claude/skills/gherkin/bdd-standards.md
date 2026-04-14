# BDD Standards — Gherkin Skill Family

> **Source:** Cucumber/Gherkin specification — https://cucumber.io/docs/gherkin/reference/
> **Co-update partners:** When these standards change, update the same rules in `gherkin-scenarios/SKILL.md`, `gherkin-review/SKILL.md`, and `ralph-prompt-create/SKILL.md`.

Shared rules and format definitions used by `gherkin-scenarios` (generator) and `gherkin-review` (auditor).

---

## Scenario format

```gherkin
Feature: <feature name>

  As a <role>
  I want to <goal>
  So that <benefit>

  # --- Happy path ---

  Scenario: <descriptive title>
    Given <world state — no actions>
    When <exactly one user action>
    Then <concrete, observable outcome>
    And <additional outcome if needed>

  # --- Empty / loading states ---

  Scenario: <title>
    ...

  # --- Error cases ---

  Scenario: <title>
    ...

  # --- Edge cases ---

  Scenario: <title>
    ...
```

---

## Quality rules

Every scenario must satisfy all of the following:

1. **Concrete and testable** — each `Given/When/Then` line describes something a test runner or human tester can verify directly. No vague phrases:
   - Bad: `Then it works correctly` / `Then the state is shown` / `Then the UI updates`
   - Good: `Then I see "Board config saved"` / `Then the Save button is disabled`

2. **One outcome per scenario** — do not combine unrelated assertions in one scenario. Each scenario tests exactly one distinct outcome.

3. **Given = world state, not action** — `Given` clauses set up preconditions; they must not describe actions the user takes. Actions belong in `When`.

4. **When = one action** — each scenario's `When` block describes a single user action (click, type, select, submit). Chains of actions belong in separate scenarios or in a background.

5. **Then = observable UI outcome** — prefer quoting exact UI text, button labels, or field states. Avoid implementation-level language (e.g. "the API is called", "<datastore> is updated").

6. **Group with `# ---` headers** — scenarios are grouped under comment headers:
   - `# --- Happy path ---`
   - `# --- Empty / loading states ---`
   - `# --- Error cases ---`
   - `# --- Edge cases ---`

7. **Scenario titles are descriptive** — titles summarise the condition being tested, not just the action (e.g. `Save is blocked when all columns are excluded`, not `Test save`).

---

## Scenario category definitions

| Category | What it covers |
|---|---|
| **Happy path** | The primary success flow end-to-end; may include multiple scenarios for distinct success variants |
| **Empty / loading states** | What the user sees before data exists or while data is being fetched |
| **Error cases** | Each distinct failure mode: validation errors, network errors, permission denials |
| **Edge cases** | Boundary conditions, undo/cancel, concurrent edits, stale data, page refresh behaviour |

A complete feature file should have at least one scenario in each category (except edge cases, which may be absent if none apply).

---

## Output file template

```markdown
# <Feature name> — UI acceptance criteria

> Generated: <YYYY-MM-DD>
> Phase: <phase number and slug if known, else "TBD">

<full Gherkin block>
```

Files are written to `docs/ux/<feature-slug>.md` where `<feature-slug>` is a short kebab-case name (e.g. `board-config-columns`, `label-role-editor`).
