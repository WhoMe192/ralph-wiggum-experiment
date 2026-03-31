# /init-project — Interactive Project Initialisation

You are running the **init-project** skill. Your job is to gather project details from the user, update the repository files to configure the devcontainer and GitHub settings, and commit everything so the devcontainer starts without error.

## Step 1 — Gather project basics

Use AskUserQuestion to collect (in up to 4 questions per call):

**Round 1** — ask all four at once:
1. "What is your project name?" (header: "Project name") — options: offer a reminder that this becomes the devcontainer name and GitHub repo slug; since it is free text, include at least one placeholder option like "my-project" so the user can type their own via Other.
2. "What is your GitHub owner or org?" (header: "GitHub owner") — options similar placeholder.
3. "What is a one-line description of the project?" (header: "Description") — placeholder option.
4. "Which runtime / tech stack will this project use?" (header: "Tech stack") — options:
   - Node.js 22 (default)
   - Python 3.12
   - Go 1.22
   - Rust
   - Base Ubuntu (other language)

After round 1, if the tech stack answer was "Base Ubuntu (other language)", ask a follow-up free-text question for the exact devcontainer image the user wants.

**Round 2** — ask up to 4 at once:
1. "Which ports should the devcontainer forward?" (header: "Ports", multiSelect: true) — options: 3000 (Node), 8000 (Django/FastAPI), 8080 (Go/general), 5173 (Vite), None.
2. "Should any extra VS Code extensions be installed?" (header: "Extensions", multiSelect: true) — options: ESLint, Prettier, Pylance, GitLens, Docker, None.
3. "What visibility should the GitHub repo have?" (header: "Repo visibility") — options: Public, Private.
4. "Should the repo have a description set on GitHub?" (header: "GH description") — options: Yes (use the description I entered), No.

## Step 2 — Map answers to configuration values

Use this image map:
| Tech stack answer | devcontainer image |
|---|---|
| Node.js 22 | mcr.microsoft.com/devcontainers/javascript-node:22 |
| Python 3.12 | mcr.microsoft.com/devcontainers/python:3.12 |
| Go 1.22 | mcr.microsoft.com/devcontainers/go:1.22 |
| Rust | mcr.microsoft.com/devcontainers/rust:1 |
| Base Ubuntu (other language) | mcr.microsoft.com/devcontainers/base:ubuntu |
| Custom (user-supplied) | whatever the user typed |

Extension IDs:
- ESLint → dbaeumer.vscode-eslint
- Prettier → esbenp.prettier-vscode
- Pylance → ms-python.vscode-pylance
- GitLens → eamodio.gitlens
- Docker → ms-azuretools.vscode-docker

## Step 3 — Implement the configuration

Make all file edits using the Edit or Write tools (never sed/awk via Bash).

### 3a. `.devcontainer/devcontainer.json`

- Set `"name"` to `"<PROJECT_NAME> Dev Environment"`
- Set `"image"` to the mapped image
- Set `"forwardPorts"` to the selected port numbers (integers, not strings); omit if none
- Set `"customizations.vscode.extensions"` to the list of extension IDs; omit if none

Read the file first, then edit it in place. Preserve all comments.

### 3b. `README.md`

Rewrite the entire file to a clean project README using this template (fill in the values):

```markdown
# <PROJECT_NAME>

<PROJECT_DESC>

## Getting Started

### Prerequisites

- [VS Code](https://code.visualstudio.com/) with the
  [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  extension, **or**
- [GitHub Codespaces](https://github.com/features/codespaces)

### Open in a devcontainer

1. Clone the repo and open the folder in VS Code
2. When prompted, click **Reopen in Container**
3. Wait for the setup to finish — this installs Claude Code CLI automatically

Or open directly in Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/<GITHUB_OWNER>/<PROJECT_NAME>)

### Authenticate

On first container start, an auth check runs automatically. Follow any prompts:

- **GitHub CLI:** `gh auth login`
- **Claude Code:** `claude` (follow the login prompt)

## Usage

<!-- Add your project-specific usage instructions here -->

## Development

This project uses a devcontainer with Claude Code pre-installed.
See [CLAUDE.md](CLAUDE.md) for project conventions and AI-assisted development guidelines.
```

### 3c. `CLAUDE.md`

Replace `[Your Project Name]` with the actual project name. Do not change anything else.

### 3d. GitHub repo settings (only if gh CLI is available)

Run `gh auth status` silently to check. If authenticated:
- If user chose to set description: run `gh repo edit --description "<PROJECT_DESC>"`
- If user chose Private: run `gh repo edit --visibility private`
- If user chose Public: run `gh repo edit --visibility public`

Do NOT push or create the repo — only edit metadata on the existing remote.

## Step 4 — Validate the devcontainer config

Run `cat .devcontainer/devcontainer.json` to confirm the JSON is well-formed and the image line reflects the user's choice. If the file is malformed, fix it before committing.

## Step 5 — Delete init.sh if it still exists

Check with `test -f init.sh && echo EXISTS` and remove it with Bash `rm init.sh` if present. This is part of clean project initialisation.

## Step 6 — Commit

Stage only the files you changed:
```
git add .devcontainer/devcontainer.json README.md CLAUDE.md
git add -u  # picks up deleted init.sh if applicable
```

Commit with:
```
git commit -m "Initialise project: <PROJECT_NAME>

Configure devcontainer for <TECH_STACK>, set project metadata,
and update README and CLAUDE.md.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

## Step 7 — Report

Tell the user:
- What was changed and committed
- How to open the devcontainer (VS Code: Reopen in Container / Codespaces badge)
- Any GitHub metadata changes made
- That they can now run `claude` inside the container to start working