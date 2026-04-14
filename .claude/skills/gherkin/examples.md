# Gherkin Examples: Bad vs Good

Reference calibration for writing Gherkin scenarios. Bad examples show the four most common rule violations. Good examples are drawn from `docs/ux/board-config-refinements.md` in this repo — the reference quality standard.

## Contents

- [Anti-patterns summary](#anti-patterns-summary)
- [Rule 4: System event in `When`](#rule-4-system-event-in-when)
- [Rule 4: Multiple actions in `When`](#rule-4-multiple-actions-in-when)
- [Rule 3: Action embedded in `Given`](#rule-3-action-embedded-in-given)
- [Rule 1: Vague `Then` clause](#rule-1-vague-then-clause)
- [Rule 4: System condition in `When` (error cases)](#rule-4-system-condition-in-when-error-cases)

---

## Anti-patterns summary

| Anti-pattern | Bad example | Why it fails |
|---|---|---|
| System event in `When` | `When the page finishes loading` | Not a user action — the trigger is the navigation, not the load completing |
| Multi-action `When` | `When I click the field / And I type text / And I click Save` | Only the final action is being tested; setup belongs in `Given` |
| Action in `Given` | `And I click "Save board config"` inside `Given` | `Given` is world state, not steps the user takes |
| Vague `Then` | `Then I see an error message indicating the save failed` | No quoted text — a tester cannot verify this without guessing |
| System condition in `When` (errors) | `And the network is unavailable` in `When` block | A network state is a precondition, not a user action |

---

## Rule 4: System event in `When`

### Bad
```gherkin
Scenario: Named labels appear on page load
  Given I am on the Board Config page
  And my board has labels named "Clients" and "People"
  When the page finishes loading
  Then each named label appears as a row
```

**What goes wrong:** `When the page finishes loading` is a system event triggered by the browser — not something the user *does*. A test runner cannot reliably target it, and it obscures the real trigger (navigation).

### Good
```gherkin
Scenario: Named <external-label>s appear as editable rows on page load
  Given I am on the Board Config page
  And my connected <external-board> has labels with names (e.g. "Clients", "People", "event")
  When I navigate to the Board Config tab
  Then each named label appears as a row showing its colour swatch, its label names, and an empty description input
  And the description input for each row is editable
```

**Why this works:** The `When` names the user action (navigation); the system's response is the `Then`. Both are observable and testable.

---

## Rule 4: Multiple actions in `When`

### Bad
```gherkin
Scenario: User types a description and saves
  Given I am on the Board Config page
  And the "Sky" label row is visible
  When I click the description field for the "Sky" row
  And I type "Client companies (e.g. Melita, Zooplus)"
  And I click "Save board config"
  Then I see a confirmation message "Board config saved"
```

**What goes wrong:** Three actions are chained in `When`. The scenario is testing the save outcome but buries it in setup steps. If the click or typing fails, the scenario fails for the wrong reason.

### Good
```gherkin
Scenario: User saves a label colour description successfully
  Given I am on the Board Config page
  And the "Sky" label row is visible with an editable description field
  And I have typed "Client companies (e.g. Melita, Zooplus)" into the "Sky" description field
  When I click "Save board config"
  Then I see a confirmation message "Board config saved"
  And the "Sky" row shows "Client companies (e.g. Melita, Zooplus)" on next page load
```

**Why this works:** Setup (opening and typing in the field) is world state in `Given`. The single testable action — clicking Save — is the `When`. The outcome is unambiguous.

---

## Rule 3: Action embedded in `Given`

### Bad
```gherkin
Scenario: Blank description excluded from prompt context
  Given I am on the Board Config page
  And the "Orange" label row has no description entered
  And I click "Save board config"
  When I expand "Prompt context preview (BOARD_CONTEXT)"
  Then the "Orange" label is not mentioned in the BOARD_CONTEXT preview
```

**What goes wrong:** `And I click "Save board config"` is an action buried inside `Given`. The `Given` block describes world state; actions belong in `When`. This scenario has two user actions, making it untestable as written.

### Good
```gherkin
Scenario: Label description left blank is excluded from the Claude prompt context
  Given I have saved the board config with the "Orange" label description left blank
  When I expand "Prompt context preview (BOARD_CONTEXT)"
  Then the "Orange" label is not mentioned in the BOARD_CONTEXT preview
```

**Why this works:** The save is expressed as a past-tense precondition (`I have saved...`) — world state, not an action. The single observable action is expanding the preview. One `When`, one `Then`.

---

## Rule 1: Vague `Then` clause

### Bad
```gherkin
Scenario: Save fails due to network error
  Given I am on the Board Config page
  And I have typed a description
  When I click "Save board config"
  Then I see an error message indicating the save failed
  And my changes are preserved
```

**What goes wrong:** `Then I see an error message indicating the save failed` quotes no text — a tester must guess what the message says. `And my changes are preserved` is similarly vague.

### Good
```gherkin
Scenario: Save board config fails due to a network error
  Given I am on the Board Config page
  And I have typed a description for at least one label row
  And the network is unavailable
  When I click "Save board config"
  Then I see an error message "Failed to save board config"
  And my typed descriptions are still visible in the form
```

**Why this works:** Exact UI text is quoted. `still visible in the form` is a concrete, observable state a tester can check without interpretation.

---

## Rule 4: System condition in `When` (error cases)

### Bad
```gherkin
Scenario: Refresh from <service> fails
  Given I am on the Board Config page
  When I click "Refresh from <service>"
  And the <external-API> request fails
  Then I see an error message indicating the refresh failed
```

**What goes wrong:** `And the <external-API> request fails` is a system condition (a precondition for the error path), not a user action. It belongs in `Given`. Mixing it into `When` makes the scenario unexecutable — you cannot "do" an API failure as a step.

### Good
```gherkin
Scenario: Refresh from <service> fails
  Given I am on the Board Config page
  And the <external-API> is unavailable
  When I click "Refresh from <service>"
  Then I see an error message "Failed to refresh from <external-service>"
  And the existing label rows and descriptions remain unchanged
```

**Why this works:** The API outage is a `Given` precondition set up before the test begins. The user action (`When`) and observable outcome (`Then`) are each a single, testable statement.
