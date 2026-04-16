---
name: adr-review
description: >
  Quality review an existing ADR before approval. Checks structure, content, accuracy,
  and style. Use before approving or when a draft needs a quality gate.
  Triggers: 'review adr', 'adr quality check', '/adr-review'.
argument-hint: "<adr-number or filename>"
allowed-tools: Read, Glob
---

# Quality review an existing ADR

**Target**: $ARGUMENTS

**Inputs:**
- Required: ADR number (e.g. `006`) or filename (e.g. `docs/adr/006-*.md`) passed as `$ARGUMENTS`
- Optional: ADR content pasted directly into the prompt
- If no argument provided: ask the user "Which ADR should I review? Provide a number or filename."

## Step 1: Locate the ADR

- If a number is provided (e.g. `006`), find `docs/adr/006-*.md`
- If a filename is provided, use it directly
- If content is pasted, use that
- **If no matching file is found:** emit "Error: No ADR found matching '[identifier]'. Check the number or run `ls docs/adr/` to list available ADRs." and stop — do not proceed with a guess
- **If multiple files match** (e.g. glob returns >1 result for a number): list all matches and ask "Which ADR did you mean?" — do not proceed until the user selects one
- **If a required section is present but empty** (heading exists, no content below it): flag it as ❌ Missing with "Section heading found but content is empty."

## Step 2: Structure Review

- Verify the file is in `docs/adr/` with the correct naming format (`NNN-description.md`)
- Check the title format: `# ADR NNN: Title`
- Check all required sections are present:
  - Background
  - Alternatives Considered (at least 2 options)
  - Decision
  - Consequences
  - Related ADRs (may be "None" if genuinely standalone)
  - References (may be empty if no external links needed)
- Validate section ordering matches the template

## Step 3: Content Review

Score each dimension as ✅ / ⚠️ / ❌ using these observable criteria:

- **Background**: ✅ if it names (a) the current state/problem, (b) at least one affected component or system, and (c) any known constraint. ⚠️ if one of (a–c) is absent. ❌ if two or more are absent.
- **Alternatives**: ✅ if there are ≥2 options each with ≥1 named pro AND ≥1 named con. ⚠️ if any option lists only pros or only cons. ❌ if fewer than 2 options, or if any option is a trivially dismissed non-starter with no real con stated.
- **Decision**: ✅ if the first sentence starts with "We will". ⚠️ if the intent is clear but the sentence does not start with "We will". ❌ if the decision is absent or ambiguous.
- **Consequences**: ✅ if it contains at least one positive outcome AND at least one trade-off or risk. ⚠️ if only positives or only risks are listed. ❌ if the section is absent or empty.
- **Related ADRs**: ✅ if relationships are described with a verb ("supersedes", "extends", "conflicts with") or explicitly state "None". ⚠️ if ADRs are listed but relationships are unexplained. ❌ if section is absent.
- **References**: ✅ if all URLs are present and plausible (no hallucinated domains). ❌ if any URL looks fabricated or does not resolve to a real domain.

## Step 4: Style Review

- UK English spellings (organisation, behaviour, colour, licence)
- Formal, professional tone
- No filler words ("basically", "essentially", "obviously")
- No hedging language ("might", "could") in the Decision section
- Concise and direct

## Step 5: Technical Accuracy

- Technical claims are verifiable and correct
- Terminology is used consistently and correctly
- No contradictions with existing accepted ADRs in `docs/adr/`
- Technology names match what is actually used in the project

## Output

Present findings grouped by severity. **Every ⚠️ or ❌ finding must include:**
1. A quoted evidence excerpt (the exact text from the ADR that triggered the finding)
2. Exact text to add or replace (so the author can act without further research)

```text
ADR Review — ADR NNN: Title
════════════════════════════

CRITICAL (must fix before approval)
  ✗ Decision section does not start with "We will..."
    Evidence: "The chosen approach is to use Cloud Run."
    Fix: Replace with "We will use Cloud Run for all service deployments."

HIGH (strongly recommended)
  ⚠ Background provides insufficient context for a new reader
    Evidence: "We need a deployment platform."
    Fix: Expand to describe the current state, the problem being solved, and any constraints.

Overall: Needs Work
════════════════════════════
```

Overall assessment: **Ready** / **Needs Work** / **Major Revision**

Selection rules:
- **Ready**: zero CRITICAL findings, zero HIGH findings
- **Needs Work**: no CRITICAL findings but one or more HIGH or MEDIUM findings
- **Major Revision**: one or more CRITICAL findings

Offer to run `/adr-refine` to address issues interactively.

## Idempotency

This skill is **read-only**: it reads files with `Read`/`Glob` and emits a report. It writes no files and posts no GitHub comments. Running this skill twice on the same ADR produces the same report.

## Standards and co-update partners

**ADR structure rules** — shared with `adr-check`, `adr-new`.

- Required section names and ordering follow the convention in `docs/adr/` and enforced by `adr-check`.
- Style rules (UK English, "We will..." decision format, filler-word list) are maintained here and in `adr-new`.

**Co-update trigger:** If required section names change, or the "We will..." convention is revised, update `adr-review`, `adr-check`, and `adr-new` together.
