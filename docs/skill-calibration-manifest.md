# Skill Calibration Manifest

Canonical strong and weak calibration references for each skill. Calibration pairs live
alongside each skill as `.claude/skills/<skill>/examples.md` so the skill is self-contained
and portable. This manifest is an index into those files.

**Maintenance rule:** when a skill's calibration content changes, update that skill's
`examples.md` directly. This manifest only needs editing when a skill is added, removed,
or its calibration source changes category.

---

## ADR skills

*These skills operate on ADR files in `docs/adr/`. Strong and weak examples are embedded
in each skill's `examples.md` as a template ADR pair (the template repo ships no committed
ADRs; downstream projects should update the in-skill examples once they have real ADRs to
calibrate against).*

| Skill | Calibration source |
|---|---|
| `adr-new` | `.claude/skills/adr-new/examples.md` §Good |
| `adr-check` | `.claude/skills/adr-check/examples.md` §Good / §Bad |
| `adr-review` | `.claude/skills/adr-review/examples.md` §Good / §Bad |
| `adr-approve` | `.claude/skills/adr-approve/examples.md` §Good / §Bad |
| `adr-refine` | `.claude/skills/adr-refine/examples.md` §Good / §Bad |
| `adr-status` | `.claude/skills/adr-status/examples.md` §Good |
| `adr-consistency` | `.claude/skills/adr-consistency/adr-consistency-rules.md` |

---

## Phase prompt skills

*These skills operate on phase prompt directories in `prompts/phase-NN/`. Calibration is
the good/bad pair embedded in each skill's `examples.md` — no external phase reference is
required for calibration to work.*

| Skill | Calibration source |
|---|---|
| `ralph-prompt-create` | `.claude/skills/ralph-prompt-create/examples.md` §Strong / §Weak |
| `ralph-prompt-review` | `.claude/skills/ralph-prompt-create/examples.md` (reviews the same artefact) |
| `ralph-prompt-auto` | `.claude/skills/ralph-prompt-create/examples.md` (auto-generates the same artefact) |
| `ralph-pipeline` | `.claude/skills/ralph-pipeline/examples.md` §Strong / §Weak (to be populated on first completed phase) |
| `phase-batch-plan` | `prompts/phases.yaml` — registry artefact itself |
| `phase-sync` | `prompts/phases.yaml` — registry artefact itself |
| `corpus-sync` | `prompts/phase-corpus.jsonl` — corpus file itself |
| `corpus-query` | `prompts/phase-corpus.jsonl` — corpus file itself |

---

## Skill meta-skills

*These skills operate on `.claude/skills/*/SKILL.md` files.*

| Skill | Calibration source |
|---|---|
| `skill-review` | `.claude/skills/skill-review/examples.md` §Good / §Bad (any committed skill serves as an artefact) |
| `skill-improver` | `.claude/skills/skill-improver/examples.md` §Good / §Bad |

---

## Infrastructure and CI skills

*CI skills are GCP-Cloud-Build-specific by design and ship with a GCP-ONLY banner. See
each SKILL.md for required env vars.*

| Skill | Calibration source |
|---|---|
| `fix-ci` | `.claude/skills/fix-ci/examples.md` §Good / §Bad (populate from your project's CI runs) |
| `devcontainer-check` | `.devcontainer/devcontainer.json` — target artefact itself |
| `ralph-pipeline` / `ralph-pipeline-complete` | `.claude/skills/ralph-pipeline/examples.md` |

---

## Documentation and README skills

| Skill | Calibration source |
|---|---|
| `readme-check` | `.claude/skills/readme-check/readme-check-rules.md` + your project's `README.md` |
| `settings-hygiene` | `.claude/settings.json` — target artefact itself |

---

## Issue skills

*These skills operate on GitHub issues. Reference by issue number, not file path.*

| Skill | Calibration source |
|---|---|
| `issue-readiness-check` | `.claude/skills/issue-readiness-check/r1-r9-rubric.md` + the most recent issue that passed readiness |
| `issue-refine` | Same rubric; the most recent refined issue in the repo |

---

## BDD and diagram skills

| Skill | Calibration source |
|---|---|
| `gherkin` | `.claude/skills/gherkin/bdd-standards.md` + `.claude/skills/gherkin/examples.md` |
| `likec4` | `.claude/skills/likec4/dsl-reference.md` + the most recent committed `.c4` model |

---

## Workflow and orchestration skills

*These skills have no single artefact — they execute processes. Calibration is a reference
run recorded in each skill's `examples.md`.*

| Skill | Calibration source |
|---|---|
| `ralph-preflight` | `.claude/skills/ralph-preflight/examples.md` (the most recent phase directory that passed all checks) |
| `ralph-guardrails` | `.claude/skills/ralph-guardrails/SKILL.md` — embedded rule set |
| `ralph-parallel-subagents` | `.claude/skills/ralph-parallel-subagents/SKILL.md` — embedded workstream table |
| `smart-commit` | `.claude/skills/smart-commit/scripts/` — runnable reference |

---

## Maintenance notes

- Each skill's `examples.md` is the single source of truth for its calibration pair.
  Update it directly rather than adding details here.
- When populating a skill's `examples.md` for the first time, draw the strong example from
  the most recent successful invocation in your project and the weak example from the most
  recent corrective run.
- This manifest is an index only — it should not contain calibration content.
