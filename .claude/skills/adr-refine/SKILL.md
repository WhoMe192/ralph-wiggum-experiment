---
name: adr-refine
description: >
  Iteratively improve a draft ADR: fill gaps, strengthen justifications, clarify wording
  via coaching. Use after /adr-new or when a draft needs depth.
  Triggers: 'refine adr', 'improve adr', 'iterate on adr', '/adr-refine'.
argument-hint: "<adr-number or filename>"
disable-model-invocation: true
allowed-tools: Read, Edit, Glob
---

# Iteratively improve a draft ADR

**Target**: $ARGUMENTS

## When to use / not use

**Use when:** a draft ADR exists but needs development — context gaps, thin justifications, or unclear wording. Typical triggers: immediately after `/adr-new`, or when a reviewer asks for more depth before approval.

**Do not use when:**
- The ADR is already in Accepted status — use `/adr-approve` instead.
- You need to check cross-ADR contradictions or temporal conflicts — use `/adr-consistency` instead.
- No draft file exists yet — use `/adr-new` to create one first.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `$ARGUMENTS` | Yes | ADR number (e.g. `006`) or filename. Glob-matched against `docs/adr/`. |

## Step 1: Locate the ADR

- If a number is provided (e.g. `006`), glob `docs/adr/006-*.md`
- If a filename is provided, use it directly
- Read the full file

**Error guards (checked before proceeding):**

- **File not found:** If the glob returns zero matches, stop and output: `Error: No ADR file matching "docs/adr/<argument>-*.md" found. Check the number or provide the full filename.`
- **Ambiguous glob:** If the glob returns more than one match, stop and output: `Error: Multiple files match "<argument>". Found: <list>. Provide the exact filename.`
- **Empty section:** If a required section header is present but its body is entirely placeholder text (e.g. `<…>`) or blank, flag it during Step 2 rather than skipping it silently.

## Step 2: Identify Improvement Areas

Assess the draft against these observable focus areas. Score each as ✅ (adequate) or ❌ (needs work):

1. **Background** — Does the section contain ≥2 paragraphs? Does it name the specific trigger (incident, requirement, or deadline that made the status quo unacceptable)?

2. **Alternatives** — Are there ≥2 options? Does each option have at least one Pro and one Con listed? Are the Cons for the chosen option present (not just the unchosen options)?

3. **Decision justification** — Does the Decision body (beyond "We will...") name which alternative was selected AND reference at least one of the alternatives' Cons as the reason it was rejected?

4. **Consequences specificity** — Do consequences avoid vague language? Fail if any consequence uses phrases like "may improve", "could reduce", or "might help" without a concrete measure. Pass if at least one consequence gives a specific metric or observable outcome.

5. **Technical accuracy** — Do technology names match what is in the codebase? (e.g. `tofu` not `terraform`, correct package names, matching version numbers.)

6. **Completeness** — Are all six required sections present and non-empty: Background, Alternatives Considered, Decision, Consequences, Related ADRs, References?

## Step 3: Coach Through Improvements

Ask targeted questions to fill the most important gaps first. Do not ask more than two
questions at a time — wait for answers before asking more.

Examples:

- "What was the trigger for this decision — was there a specific incident, requirement, or
  constraint that made the status quo no longer acceptable?"
- "For Option 2, what were the strongest arguments in its favour that you considered?"
- "What is the biggest risk of the chosen approach, and how is it being mitigated?"

## Step 4: Apply Changes

After the user responds, incorporate their answers into the ADR draft. For each gap addressed, show before/after evidence using this format:

```text
> Original: "We chose Option A because it was simpler."
Suggested: "We chose Option A over Option B because Option B's dependency on a managed Kafka cluster (Con: operational overhead) would require a dedicated SRE rotation the team does not have capacity for."
```

Then show a session summary:

```text
Refinement summary — ADR NNN: Title
══════════════════════════════════════
Changes applied this round:
  ✅ Background — added trigger paragraph (paragraph 2)
     > Original: "<Expanded context of the problem...>"
     Suggested: "In March 2025, a production incident (INC-4421) exposed that..."
  ✅ Alternatives — added Cons for chosen option (Option 2)
  ⏭  Consequences — no changes requested

Remaining gaps (❌ from Step 2):
  - <area name>: <one-line description of what still needs work>

Ready to run /adr-check? (yes / continue refining)
```

Repeat Steps 3–4 until the user is satisfied.

## Verdict

After Step 2 assessment, report a verdict from this enum:

| Verdict | Meaning |
|---------|---------|
| `READY` | All six Step 2 items score ✅ — offer to run `/adr-check` immediately. |
| `NEEDS_WORK` | One or more items score ❌ — proceed to Step 3 coaching. |
| `BLOCKED` | File not found, ambiguous match, or user abandons — stop with named error output (see Step 1 error guards). |

## Success & Failure Criteria

**Success:** All six Step 2 items score ✅ and the user confirms refinement is complete. The ADR file is updated on disk and `/adr-check` is offered.

**Failure conditions and remediation:**

| Condition | Named output | Remediation |
|-----------|--------------|-------------|
| File not found | `Error: No ADR file matching …` | Stop; prompt user to check the number or supply the full filename. |
| Ambiguous glob (>1 match) | `Error: Multiple files match …` | Stop; list matches and ask user to specify exact filename. |
| Required section entirely empty after coaching | `Warning: Section <name> still empty` | Ask one more targeted question; if user declines, leave a `<!-- TODO: … -->` marker and note in summary. |
| User abandons mid-session | `Session ended without completing refinement.` | List remaining ❌ gaps in the final message so the user can resume later. |

## Idempotency

Re-running `/adr-refine` on an already-refined ADR is safe. If all Step 2 items already score ✅, the skill reports verdict `READY` and makes no edits. If the ADR has been partially refined since the last run, the skill detects existing improvements (non-placeholder text, present Cons, specific metrics) and skips coaching questions for those areas, only asking about remaining gaps. No Edit call is made unless the user approves a specific suggested rewrite.

## Style Requirements

- UK English spellings
- Formal, professional tone
- Decision always starts with "We will..."
- No filler words or hedging language in the Decision section
- Concise and direct throughout

Offer to run `/adr-check` when refinement is complete.

## Calibration

- **Strong:** `docs/adr/007-multi-environment-strategy-dev-uat-prod.md` — most recently refined ADR; rich Background with multiple paragraphs, ≥2 alternatives with structured pros/cons, Decision starts "We will...", specific Consequences. Should score ≥5 ✅ in the Step 2 assessment.
- **Weak:** `docs/adr/001-automation-platform-and-orchestration-architecture.md` — predates the current template; sections are thinner than the current standard. Should surface multiple improvement opportunities.

## Standards

**Design standard:** This skill is authored against `docs/skill-design-standards.md`. Any changes to the rubric dimensions (RC, OA, EH, ID, SC, TR, OF) in that document should be reflected here.

**Co-update list:** The following skills share ADR workflow contracts and must be reviewed for consistency whenever this skill is updated:

| Skill | Relationship |
|-------|-------------|
| `adr-new` | Creates the draft that `adr-refine` acts on; section headers and placeholder conventions must stay in sync. |
| `adr-check` | Runs the mechanical completeness gate that `adr-refine` offers at the end of each session; Step 2 criteria here must align with `adr-check` pass/fail rules. |
| `adr-review` | Qualitative review that follows refinement; its quality bar informs the ✅/❌ thresholds in Step 2. |
| `adr-approve` | Terminal state skill; `adr-refine` must not be used on ADRs already handed to `adr-approve`. |
