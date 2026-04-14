---
name: gherkin-scenarios
description: Generates Gherkin/BDD acceptance scenarios for a UI feature through a structured clarifying conversation. Sub-flow of the /gherkin skill.
disable-model-invocation: true
allowed-tools:
  - AskUserQuestion
  - ToolSearch
  - Read
  - Write
---

# Gherkin Scenario Generator

**First:** Read `.claude/skills/gherkin/bdd-standards.md` for the canonical scenario format, quality rules, category definitions, and output file template. Then read `.claude/skills/gherkin/examples.md` for bad→good rewrites of the most common violations. Apply both throughout this flow.

Generates complete Gherkin/BDD scenarios for a UI feature by asking focused clarifying questions one at a time, then writes a ready-to-reference file in `docs/ux/`.

## How to invoke

The invoker may provide:
- A feature description inline (e.g. "board config page where users manage label mappings")
- Context passed from `ralph-prompt-create` (deliverable list + phase goal)
- No argument — ask what the feature is first

Fetch `AskUserQuestion` if not yet available: `ToolSearch select:AskUserQuestion`.

**Do not write scenarios until all questions are answered.** Ask one at a time.

---

## Question sequence

Before asking questions, state the feature you are generating scenarios for (one sentence) so the user can confirm or correct it.

---

**Q1 — User and goal**
> Who is using this UI feature, and what is the single thing they are trying to accomplish?

*Drives: the `As a <role>, I want to <goal>` framing and the primary happy-path scenario.*

---

**Q2 — Entry point and preconditions**
> How does the user get to this UI? What must be true before they arrive (e.g. logged in, data already exists, board selected)?

*Drives: `Given` clauses — the world state before any action.*

---

**Q3 — Happy path actions**
> Walk through the exact steps the user takes to complete the goal successfully. What do they click, type, or select, and in what order?

*Drives: `When` clauses for the primary scenario. If the user describes a sequence of actions (e.g. "open field → type → click Save"), each action that produces a distinct observable outcome becomes its own scenario — not a chain of `And` steps under a single `When`.*

---

**Q4 — Success outcome**
> What does the user see or experience when it works correctly? Include any UI changes, confirmation messages, or what the page shows after the action completes.

*Drives: `Then` clauses for the primary scenario. Focus on observable UI state — not backend or database effects.*

---

**Q5 — Empty and loading states**
> What does the UI show when there is no data yet? Is there a loading state the user might see?

*Drives: separate empty-state and loading-state scenarios.*

---

**Q6 — Error and validation cases**
> What can go wrong? List each failure mode (invalid input, network error, permission denied, etc.) and what the UI should show for each.

*Drives: one scenario per distinct error condition.*

---

**Q7 — Edge cases**
> Are there any boundary conditions or less-obvious interactions? (e.g. maximum item counts, concurrent edits, undo/cancel behaviour, behaviour on page refresh)

*Drives: additional edge-case scenarios. If none, confirm and skip.*

---

## After all questions are answered

Draft all scenarios internally, then run a self-check before writing the file. For every scenario, verify:

1. `When` contains exactly one user action — not a system event (`page finishes loading`) and not a chain of `And` actions
2. `Given` contains only world state — no actions the user takes (no `I click`, `I type`, `I submit`)
3. `Then` quotes exact UI text where possible — no vague phrases like "an error message" or "the state updates"
4. Each scenario tests exactly one outcome — split if there are two unrelated `Then` assertions

Fix any violations before writing. Do not write the file until all scenarios pass the self-check. If any corrections were made, note ≥1 correction to the user before writing — e.g. *"Self-check: fixed 3 scenarios (moved setup actions from `When` to `Given`, replaced vague `Then` clauses with quoted UI text)."* This is skipped if no corrections were needed.

Generate scenarios using the format and quality rules from `bdd-standards.md`.

## Output

1. Before writing, check whether `docs/ux/<feature-slug>.md` already exists:
   ```bash
   test -f docs/ux/<feature-slug>.md && echo "EXISTS" || echo "NEW"
   ```
   If it exists, ask the user: "A scenarios file already exists at `docs/ux/<feature-slug>.md`. Overwrite it, or run the Review flow instead?"

2. **Write** the file to `docs/ux/<feature-slug>.md` using the file template from `bdd-standards.md`.

3. **Confirm** the file path to the caller.

4. **Auto-review:** Read `.claude/skills/gherkin/gherkin-review/SKILL.md` and execute it on the file just written, starting from **Step 2** (skip Step 1 — the file path is already known). Apply fixes if the user accepts them.

5. If invoked from `ralph-prompt-create`, also state:
   > "Scenarios saved to `docs/ux/<feature-slug>.md`. They will be added to the Self-verification section of your prompt under `### UI acceptance criteria`."

   If invoked standalone, state the file path and remind the user:
   > "Reference this file in your phase prompt's Self-verification section under `### UI acceptance criteria`."
