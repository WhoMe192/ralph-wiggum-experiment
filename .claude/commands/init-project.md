# /init-project — Interactive Project Initialisation

You are running the **init-project** skill. Gather project details interactively, update repository files to configure the devcontainer and GitHub settings, then commit so the devcontainer can start without error.

---

## Step 1 — Gather project details (Round 1)

Use **AskUserQuestion** with exactly these 4 questions in one call:

```
Question 1:
  question: "What is your project name? (becomes the repo slug and devcontainer name)"
  header: "Project name"
  multiSelect: false
  options:
    - label: "my-project"       description: "Example — type your own name via Other"
    - label: "my-api"           description: "Example — type your own name via Other"

Question 2:
  question: "What is your GitHub username or organisation?"
  header: "GitHub owner"
  multiSelect: false
  options:
    - label: "my-username"      description: "Example — type your own via Other"
    - label: "my-org"           description: "Example — type your own via Other"

Question 3:
  question: "One-line project description"
  header: "Description"
  multiSelect: false
  options:
    - label: "A project using Claude Code"   description: "Generic default"
    - label: "Custom"                        description: "Type your own via Other"

Question 4:
  question: "Which runtime / tech stack will this project use?"
  header: "Tech stack"
  multiSelect: false
  options:
    - label: "Node.js 22"       description: "JavaScript / TypeScript (Recommended)"
    - label: "Python 3.12"      description: "Python applications and data science"
    - label: "Go 1.22"          description: "Go backend services"
    - label: "Other / custom"   description: "Rust, base Ubuntu, or a custom image"
```

If the user chose **"Other / custom"** for tech stack, make a second AskUserQuestion call:

```
Question 1:
  question: "Which devcontainer base image should be used?"
  header: "Custom image"
  multiSelect: false
  options:
    - label: "mcr.microsoft.com/devcontainers/rust:1"          description: "Rust"
    - label: "mcr.microsoft.com/devcontainers/base:ubuntu"     description: "Base Ubuntu"
    - label: "Custom image URL"                                 description: "Type your own via Other"
```

---

## Step 2 — Gather configuration options (Round 2)

Use **AskUserQuestion** with exactly these 4 questions in one call:

```
Question 1:
  question: "Which ports should the devcontainer forward? (select all that apply)"
  header: "Ports"
  multiSelect: true
  options:
    - label: "3000"   description: "Node.js / React dev server"
    - label: "8000"   description: "Django / FastAPI"
    - label: "8080"   description: "Go / general HTTP"
    - label: "5173"   description: "Vite dev server"

Question 2:
  question: "Which VS Code extensions should be pre-installed? (select all that apply)"
  header: "Extensions"
  multiSelect: true
  options:
    - label: "ESLint"     description: "dbaeumer.vscode-eslint"
    - label: "Prettier"   description: "esbenp.prettier-vscode"
    - label: "Pylance"    description: "ms-python.vscode-pylance"
    - label: "GitLens"    description: "eamodio.gitlens"

Question 3:
  question: "What should the GitHub repository visibility be?"
  header: "Visibility"
  multiSelect: false
  options:
    - label: "Public"    description: "Visible to everyone on GitHub"
    - label: "Private"   description: "Only visible to you and collaborators"

Question 4:
  question: "Should the GitHub repo description be set from your project description?"
  header: "GH description"
  multiSelect: false
  options:
    - label: "Yes"   description: "Run gh repo edit --description '...'"
    - label: "No"    description: "Leave GitHub description unchanged"
```

---

## Step 3 — Map answers to config values

**Image map:**
| Tech stack | devcontainer image |
|---|---|
| Node.js 22 | `mcr.microsoft.com/devcontainers/javascript-node:22` |
| Python 3.12 | `mcr.microsoft.com/devcontainers/python:3.12` |
| Go 1.22 | `mcr.microsoft.com/devcontainers/go:1.22` |
| Other / custom | use the image from Step 1 round 2 |

**Extension IDs:**
| Label | ID |
|---|---|
| ESLint | `dbaeumer.vscode-eslint` |
| Prettier | `esbenp.prettier-vscode` |
| Pylance | `ms-python.vscode-pylance` |
| GitLens | `eamodio.gitlens` |

**Ports:** convert selected labels to integers (e.g. "3000" → 3000).

---

## Step 4 — Update `.devcontainer/devcontainer.json`

**Read the file first** (required before any Edit call), then use Edit to make targeted replacements:

1. Replace the `"name"` value with `"<PROJECT_NAME> Dev Environment"`
2. Replace the `"image"` value with the mapped image URL
3. Replace `"forwardPorts": []` with `"forwardPorts": [<comma-separated integers>]`
   - If no ports selected, leave as `[]`
4. Replace `"extensions": []` inside `customizations.vscode` with `"extensions": [<quoted IDs>]`
   - If no extensions selected, leave as `[]`

After editing, read the file back and visually confirm the image line and name are correct. If any edit failed silently, re-apply it.

---

## Step 5 — Update `README.md`

**Read the file first**, then **Write** the entire file with this content (substituting values):

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

---

## Step 6 — Update `CLAUDE.md`

**Read the file first**, then use Edit to replace `[Your Project Name]` with `<PROJECT_NAME>`. Do not change anything else.

---

## Step 7 — Apply GitHub repo settings

Check if the gh CLI is authenticated: run `gh auth status 2>&1` and inspect the output.

**If authenticated AND a remote origin exists** (check with `git remote get-url origin 2>&1`):

- If user chose "Yes" for GH description:
  ```bash
  gh repo edit --description "<PROJECT_DESC>"
  ```
- For visibility (run as separate command, capture exit code):
  ```bash
  gh repo edit --visibility public   # or private
  ```
  Note: changing to private may require `--accept-visibility-change-consequences`. If the command fails, tell the user to run it manually with that flag.

**If not authenticated or no remote:** Skip gh commands and tell the user what to run manually.

---

## Step 8 — Remove `init.sh` if present

```bash
test -f init.sh && rm init.sh && echo "Removed init.sh" || echo "init.sh not present"
```

---

## Step 9 — Commit

Stage all changed files:
```bash
git add .devcontainer/devcontainer.json README.md CLAUDE.md
git add -u
```

Verify what will be committed with `git status`, then commit:
```bash
git commit -m "Initialise project: <PROJECT_NAME>

Configure devcontainer for <TECH_STACK> (<IMAGE>),
forward ports <PORTS_OR_NONE>, update README and CLAUDE.md.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Step 10 — Report to user

Summarise clearly:
- Devcontainer configured: image used, ports, extensions
- Files updated: devcontainer.json, README.md, CLAUDE.md
- init.sh removed (if applicable)
- GitHub metadata: what was set, or what to run manually if gh wasn't available
- Commit SHA
- **Next step:** "Open the folder in VS Code and click 'Reopen in Container', or open in Codespaces using the badge in the README."