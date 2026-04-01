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
