# Ralph-Wiggum Experiment (Template Repo)

## Overview

This is a **devcontainer template** for Claude Code + Ralph-Wiggum iterative loop
methodology. Users clone it and run `/init-project` to configure it for their own
project. The template itself is not a shipped application.

## Tech Stack

- Node.js 22 (devcontainer base image)
- Python 3.13 + duckdb, pandas, numpy, pyyaml (corpus/pipeline tooling via `pyproject.toml`)
- JavaScript (scripts: `pipeline-deps.js`, `pipeline-deps.test.js`)

## Project Structure

- `.devcontainer/` — container config, secret-fetching, auth checks
- `scripts/` — pipeline dependency tooling
- `docs/` — skill design standards and calibration manifests
- `CLAUDE.md` — pre-populated by `/init-project` for new projects

## Development

### Test

```bash
node scripts/pipeline-deps.test.js   # JS unit tests
```

### Python tooling

```bash
uv run python scripts/migrate-corpus.py   # corpus migration
```

## Devcontainer

- After container rebuilds, CLI tools (gcloud, gh, claude, tofu) may need reconfiguration.
- Always verify tool availability with `which <tool>` or `<tool> --version` before running commands that depend on them.
- Prefer apt-based installs over curl scripts or devcontainer features for gcloud and similar CLI tools — feature-based and curl installs have historically failed in this environment.
- `~/.claude.json` is a symlink to the persistent volume (`~/.claude/claude-code/claude.json`). Claude Code can silently replace it with a regular file during a session; `check-auth.sh` re-links it on the next container start.
- `fetch-secrets.sh` runs on the macOS host and reads from Keychain. In Codespaces or Linux, set `ANTHROPIC_API_KEY` and `GITHUB_TOKEN` as repo/Codespace secrets instead.
- `init.sh` in the repo root is a one-time template artifact — use `/init-project` instead; that skill deletes `init.sh` when done.

## Ralph Loop

This repo uses a ralph-loop automation mechanism.

- Do NOT modify ralph-loop config or state files unless explicitly asked.
- When running ralph-loop prompts, complete all verification checks before signaling completion.
- If a loop phase fails, log the error and surface it to the user — do not attempt to fix the loop mechanism itself.

## Skills

All skills are provided by the [ee-skills marketplace](https://github.com/Eaiger-Ent/ee-skills)
via Claude Code plugins. There are no local skill overrides in `.claude/skills/`.

To update skills to latest: `claude plugin update --scope project`
To add a new ee-skill: `claude plugin install --scope project <plugin-name>`
To contribute a local improvement back: `/submit-amendment <skill-name>`

### Installed ee-skills plugins

| Plugin | Skills provided | Category |
| --- | --- | --- |
| `ralph-loop` | `/ralph-loop`, `/cancel-ralph`, `/ralph-help` | Productivity |
| `ralph-pipeline` | `ralph-pipeline`, `ralph-guardrails`, `ralph-preflight`, `ralph-prompt-create`, `ralph-prompt-review`, `ralph-prompt-auto`, `ralph-parallel-subagents`, `phase-sync`, `phase-batch-plan` | Development |
| `adr-toolkit` | `adr-new`, `adr-check`, `adr-review`, `adr-approve`, `adr-refine`, `adr-status`, `adr-consistency` | Development |
| `skill-quality` | `skill-quality`, `skill-review`, `skill-improver` | Workflow |
| `issue-workflow` | `issue-readiness-check`, `issue-refine` | Workflow |
| `corpus` | `corpus-sync`, `corpus-query` | Workflow |
| `devcontainer-check` | `devcontainer-check` | Productivity |
| `fix-ci` | `fix-ci` | Productivity (GCP Cloud Build only) |
| `gherkin` | `gherkin` | Development |
| `likec4` | `likec4` | Development |
| `readme-check` | `readme-check` | Productivity |
| `settings-hygiene` | `settings-hygiene` | Workflow |
| `smart-commit` | `smart-commit` | Productivity |
| `ee-skills-manage` | `sync-skills`, `replace-with-marketplace`, `update-skills` | Workflow |
| `ee-skills-contribute` | `/submit-amendment` | Workflow |

### Optional dependencies

- `uv` + Python 3.13 + `duckdb` — required by `corpus-sync` / `corpus-query` (see `pyproject.toml`)
- `gh` — required by `issue-readiness-check`, `issue-refine`, `ralph-prompt-auto`, `phase-batch-plan`

### Skills requiring project customisation

- `ralph-prompt-auto` — reads this file's `## Tech Stack` section to classify phase type
- `fix-ci` — GCP Cloud Build only. Requires `CLAUDE_GCP_PROJECT` and `CLAUDE_GCP_REGION`

### GCP configuration (only if this project deploys to GCP)

| Env var | Used by | Required |
| --- | --- | --- |
| `CLAUDE_GCP_PROJECT` | `fix-ci`, `ralph-pipeline` | if invoking either skill |
| `CLAUDE_GCP_REGION` | `fix-ci`, `ralph-pipeline` | if invoking either skill |
| `CLAUDE_UAT_TRIGGER` | `ralph-pipeline` UAT step | only for UAT flow |
| `CLAUDE_UAT_SECRET` | `ralph-pipeline` secret lookup | only for UAT flow |
