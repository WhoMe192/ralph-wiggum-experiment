# [Your Project Name]

<!-- This file gives Claude Code context about your project.
     Fill in the sections below so Claude can assist you more effectively.
     Delete any sections that aren't relevant. -->

## Overview

<!-- What does this project do? What problem does it solve? -->

## Tech Stack

<!-- e.g. Node.js 22, TypeScript, React, PostgreSQL -->

## Project Structure

<!-- Describe the key directories and their purpose -->

## Development

### Build

```bash
# e.g. npm run build
```

### Test

```bash
# e.g. npm test
```

### Run

```bash
# e.g. npm start
```

## Conventions

<!-- Code style, naming conventions, patterns to follow -->

## Important Notes

<!-- Anything Claude should know: gotchas, constraints, external dependencies -->

## Devcontainer

- After container rebuilds, CLI tools (gcloud, gh, claude, tofu) may need reconfiguration.
- Always verify tool availability with `which <tool>` or `<tool> --version` before running commands that depend on them.
- Prefer apt-based installs over curl scripts or devcontainer features for gcloud and similar CLI tools — feature-based and curl installs have historically failed in this environment.

## Ralph Loop

This repo uses a ralph-loop automation mechanism.

- Do NOT modify ralph-loop config or state files unless explicitly asked.
- When running ralph-loop prompts, complete all verification checks before signaling completion.
- If a loop phase fails, log the error and surface it to the user — do not attempt to fix the loop mechanism itself.

## Skills

This template ships skills under `.claude/skills/`. Categories:

- **ADR**: `adr-new`, `adr-check`, `adr-review`, `adr-approve`, `adr-refine`, `adr-status`, `adr-consistency`
- **Ralph-loop methodology**: `ralph-prompt-create`, `ralph-prompt-review`, `ralph-prompt-auto`, `ralph-pipeline`, `ralph-pipeline-complete`, `ralph-parallel-subagents`, `ralph-guardrails`, `ralph-preflight`, `phase-sync`, `phase-batch-plan`
- **Corpus** (opt-in, requires `uv` + `duckdb`): `corpus-sync`, `corpus-query`
- **GitHub issue workflow**: `issue-readiness-check`, `issue-refine`
- **CI**: `fix-ci` (GCP-only — see header banner)
- **Skill / docs hygiene**: `skill-review`, `skill-improver`, `settings-hygiene`, `readme-check`
- **BDD**: `gherkin`, `gherkin-scenarios`, `gherkin-review`
- **Architecture**: `likec4`, `likec4-model`, `likec4-check`
- **Devcontainer**: `devcontainer-check` (gcloud/tofu conditional on this CLAUDE.md tech-stack)
- **Commit**: `smart-commit`

Calibration / standards docs: `docs/skill-design-standards.md`, `docs/skill-calibration-manifest.md`, `docs/skill-output-templates.md`.

### Optional dependencies

- `uv` + Python 3.13 + `duckdb` — required by `corpus-sync` / `corpus-query` (see `pyproject.toml`)
- `node` — required by `scripts/pipeline-deps.js` used by `ralph-pipeline`
- `gh` — required by `issue-readiness-check`, `issue-refine`, `ralph-prompt-auto`, `phase-batch-plan`

### Skills requiring project customisation

A few skills use placeholder paths (`<source-dir>`, `<test-dir>`) or require project-specific
configuration. Populate `## Tech Stack` below so the skills can infer the rest.

- `ralph-prompt-auto` — reads this file's `## Tech Stack` section to classify phase type
  and picks source directories via a manifest-file scan
- `ralph-pipeline-complete` — if using GCP Cloud Build for UAT, set `CLAUDE_GCP_PROJECT`,
  `CLAUDE_GCP_REGION`, `CLAUDE_UAT_TRIGGER`, `CLAUDE_UAT_SECRET`; otherwise the UAT step
  skips gracefully
- `fix-ci` — GCP Cloud Build only. Requires `CLAUDE_GCP_PROJECT` and `CLAUDE_GCP_REGION`

### GCP configuration (only if this project deploys to GCP)

| Env var | Used by | Required |
| --- | --- | --- |
| `CLAUDE_GCP_PROJECT` | `fix-ci`, `ralph-pipeline-complete` | if invoking either skill |
| `CLAUDE_GCP_REGION` | `fix-ci`, `ralph-pipeline-complete` | if invoking either skill |
| `CLAUDE_UAT_TRIGGER` | `ralph-pipeline-complete` UAT step | only for UAT flow |
| `CLAUDE_UAT_SECRET` | `ralph-pipeline-complete` secret lookup | only for UAT flow |
