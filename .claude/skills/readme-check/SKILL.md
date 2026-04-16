---
name: readme-check
description: >
  Review a README for quality, structure, reading age, and clarity. Use before committing,
  when auditing an existing README, or coaching authors through fixes.
  Triggers: 'readme check', 'review readme', '/readme-check'.
argument-hint: "[<file-path>]"
allowed-tools: Read, Edit, Glob, Bash
---

# Review a README for quality, structure, reading age, and clarity

**File**: $ARGUMENTS (if omitted, auto-detect README.md at git repo root)

**Do not use when:** reviewing a non-README doc — use `/adr-review` for ADRs or general prose review tools for other docs.

## Inputs

**Required:** none — auto-detects `README.md` at git repo root if `$ARGUMENTS` is omitted.
**Optional:** file path (e.g. `docs/contributing.md`)
**Missing required input:** if no argument and no `README.md` found at repo root, emit `ERROR: No README.md found at repo root — provide a file path as argument` and stop.

## Idempotency

Re-running on unchanged input produces identical output. This skill is read-only during Step 1 and Step 2; edits only occur in Step 3 with explicit user confirmation per item.

## Edge cases

- **File not found:** emit `ERROR: File not found at <path> — check the path and try again` and stop.
- **Empty file:** emit `ERROR: <filename> is empty — nothing to review` and stop.
- **Multiple READMEs found:** list them and ask "Which file would you like to review?" via AskUserQuestion.
- **File too short (<50 words):** proceed but note "Only <N> words found — review may be incomplete."
- **All errors:** every error path emits a named message — no silent failure.

## Step 0: Locate File

If a path is provided as argument, use it directly.

If no argument:

- Run `git rev-parse --show-toplevel` to find repo root
- Look for `README.md` at repo root
- If multiple README files exist, list them and ask the user which to review

## Step 1: Read and Analyse

Read the full file. Evaluate it against all nine criteria below — do not summarise first, evaluate in full.

### Evaluation Criteria

Read `.claude/skills/readme-check/readme-check-rules.md`

## Step 2: Generate Report

Present findings grouped by severity. For every finding include: the gap category, a quoted evidence excerpt from the file, a suggested rewrite, and the rationale. Use the table format below for each severity band.

```text
README Quality Report — <filename>
════════════════════════════════════

CRITICAL (must fix)

| Gap | Evidence | Suggested | Rationale |
|-----|----------|-----------|-----------|
| Missing "Getting started" section | — (section absent) | Add a "Getting started" heading with prerequisites and copy-pasteable install command | Readers cannot begin without it |
| Prerequisites not stated before install commands | Evidence: "Run `npm install`" appears on line 12 before any requirement is listed | Move Node.js ≥18 and npm ≥9 prerequisites to a "Prerequisites" block above line 12 | Assumptions must precede the step that relies on them |

HIGH (strongly recommended)

| Gap | Evidence | Suggested | Rationale |
|-----|----------|-----------|-----------|
| 6 sentences exceed 25 words — likely above Grade 9 | Evidence: "This tool is designed to allow users who are unfamiliar with the API to nonetheless be able to perform…" (line 34, 31 words) | "This tool lets users call the API without prior knowledge of its internals." | Shorter sentences lower reading age |
| 14 passive voice constructions (estimated 31% of sentences) | Evidence: "Errors are reported by the handler" (line 55) | "The handler reports errors." | Active voice is easier to scan |

MEDIUM (improve where possible)

| Gap | Evidence | Suggested | Rationale |
|-----|----------|-----------|-----------|
| 3 US English spellings | Evidence: "color" (line 14), "behavior" (line 22) | "colour", "behaviour" | UK English project convention |
| 2 bare URLs | Evidence: "https://example.com/docs" (line 45) | `[docs](https://example.com/docs)` | Bare URLs are harder to scan and may break in some renderers |
| Code block missing language identifier | Evidence: fence on line 52 opens with ` ``` ` only | Change to ` ```bash ` | Syntax highlighting aids readability |

LOW (minor polish)

| Gap | Evidence | Suggested | Rationale |
|-----|----------|-----------|-----------|
| 5 badges before first content | Evidence: Five `[![…](…)](…)` lines precede the purpose paragraph | Move badges to a footer section or after the purpose statement | First 200 words should be content, not status indicators |

Summary: 2 critical, 2 high, 5 medium, 1 low — 10 issues total
════════════════════════════════════

Would you like to work through these interactively? (yes / no)
```

## Step 3: Offer Coaching

After the report, ask whether to work through issues interactively.

If yes, work Critical → Low, one issue at a time:

- Show the problematic text
- Explain why it is an issue
- Propose a specific rewrite
- Ask for confirmation before applying with the Edit tool
- Skip or defer on request

**Fallback coaching rule:** If the user declines to fix an issue, says "skip", "later", or gives no clear direction after two exchanges on the same item, move on to the next issue without repeating the prompt. After all issues are processed (or skipped), summarise what was applied and what remains outstanding.

## Important Reminders

- Report first, coach second — never jump straight into edits
- One issue at a time during coaching
- Propose specific rewrites, not vague guidance ("try shorter sentences")
- Apply changes only after explicit user confirmation
- UK English applies throughout — use it in suggestions and report text

## Standards

The evaluation rubric in this skill is derived from the shared quality standards documented in `docs/skill-design-standards.md`. If the core section list, reading-age target, or UK English mapping table changes there, update this skill to match.

## Relationships

| Related skill | Relationship |
|---------------|-------------|
| `smart-commit` | Shares UK English writing conventions; update both if the US→UK mapping table changes |
| `adr-review` | Shares UK English rule and the principle of evidence-quoted findings |
| `adr-check` | Shares the pattern of structured gap reporting with severity bands |

## Standards and co-update partners

- **UK English rule** — project writing convention applied across all human-readable docs. If the US→UK mapping table changes, update `readme-check` and `smart-commit` together.
- **Core section list** (Purpose, Audience, Getting Started, Usage, Contributing) — derived from the README structure expected by new team members joining this project. Update if project onboarding requirements change.
- **Co-update partners:** `smart-commit` (shares writing conventions); `adr-review` (shares UK English rule).

## Calibration

- **Strong:** `docs/architecture.md` — follows project prose standards; all core sections present; UK English throughout; no badge overload. Should score no CRITICAL findings.
- **Weak:** no committed weak README example — a README that opens with a badge grid before any purpose statement is the most common HIGH finding. Update this entry when such a file is committed.
