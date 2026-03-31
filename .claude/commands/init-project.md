# /init-project — Interactive Project Initialisation

You are running the **init-project** skill. Gather project details interactively, update repository files to configure the devcontainer and GitHub settings, then commit so the devcontainer can start without error.

**Steps at a glance:**
1. Pre-flight — read current file state, check dirty tree, infer GitHub owner from remote
2. Questions round 1 — project name (kebab-case), GitHub owner, description, tech stack
3. Questions round 2 — ports, VS Code extensions, repo visibility, set GH description?
4. Map answers → devcontainer image, node feature flag, extension IDs
5. Edit `devcontainer.json` — name, image, node feature (non-Node stacks), ports, extensions; validate JSONC
6. Write `README.md` — project name, description, Codespaces badge
7. Edit `CLAUDE.md` — name, overview, tech stack, build/test/run commands
7b. Extend `.gitignore` — stack-specific entries, create if absent
8. Apply GitHub settings — `gh repo edit` description + visibility (always with `--accept-visibility-change-consequences`)
8b. Harden `setup.sh` — make plugin install non-fatal if not already guarded
9. Remove `init.sh` if present
10. Commit all changes with heredoc message
11. Report to user

---

## Pre-flight — Read current state

Before asking the user anything, gather current file contents and repo metadata. Use the dedicated tools (Read, Bash) — never use `cat` when Read is available.

1. Run via Bash: `git status --short` — if any lines appear, warn the user: "There are uncommitted changes in this repo. The init-project commit will include them. Do you want to continue?" Use AskUserQuestion with Continue / Abort options. If the user chooses Abort, stop here and tell them to commit or stash their changes first.
2. Use the **Read tool** on `.devcontainer/devcontainer.json` — note the exact current values of `"name"`, `"image"`, `"forwardPorts"`, `"extensions"`, and the `"features"` block. You will need these as `old_string` in every Edit call.
3. Use the **Read tool** on `README.md` (first 5 lines sufficient).
4. Use the **Read tool** on `CLAUDE.md` (first 10 lines sufficient).
5. Run via Bash: `test -f init.sh && echo "present" || echo "absent"`
6. Run via Bash: `git remote get-url origin 2>/dev/null || echo "no-remote"`

**From the remote URL, attempt to infer the GitHub owner:**
- SSH format: `git@github.com:OWNER/REPO.git` → owner is `OWNER`
- HTTPS format: `https://github.com/OWNER/REPO` → owner is `OWNER`
- If inferred successfully, pre-fill the GitHub owner field and **skip Question 2** in Step 1 (do not ask for something you already know). Tell the user: "Detected GitHub owner: OWNER — using that automatically."
- If the remote is absent or not a github.com URL, ask Question 2 as normal.

---

## Step 1 — Gather project details (Round 1)

Use **AskUserQuestion** with up to 4 questions in one call. If GitHub owner was inferred in Pre-flight, omit Question 2 and ask only 3 questions.

```
Question 1:
  question: "What is your project name? Use kebab-case (e.g. my-cool-app) — appears in the devcontainer name and Codespaces URL."
  header: "Project name"
  multiSelect: false
  options:
    - label: "my-project"       description: "Example — type your kebab-case name via Other"
    - label: "my-api"           description: "Example — type your kebab-case name via Other"

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

**After receiving the project name:** if it contains spaces or characters other than letters, digits, hyphens, or underscores, suggest a kebab-case version (e.g. "My Cool App" → "my-cool-app") and confirm with the user before continuing. Use this normalised name throughout.

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
  question: "Which ports should the devcontainer forward? Select all that apply, or choose Other and type 'none' if no ports are needed."
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

**Node feature flag:** Claude Code is installed via `npm` in `setup.sh`. If the chosen image is **not** Node.js 22, you must add `"ghcr.io/devcontainers/features/node:1": {}` to the `features` block so npm is available at build time. Without this the `postCreateCommand` will fail and the devcontainer will not start.

| Tech stack | Needs node feature? |
|---|---|
| Node.js 22 | No — npm is already in the base image |
| Python 3.12 | **Yes** |
| Go 1.22 | **Yes** |
| Other / custom | **Yes** (assume no npm unless user confirms) |

---

## Step 4 — Update `.devcontainer/devcontainer.json`

**Read the file first** (required before any Edit call). After reading, extract the *current* values for `"name"`, `"image"`, `"forwardPorts"`, `"extensions"`, and the `"features"` block — you must use the **exact current string** as `old_string` in each Edit call, or the edit will fail.

Apply each change as a separate Edit call:

1. Replace the current `"name": "<CURRENT_NAME>"` line with `"name": "<PROJECT_NAME> Dev Environment"`
2. Replace the current `"image": "<CURRENT_IMAGE>"` line with `"image": "<MAPPED_IMAGE>"`
3. **If a non-Node stack was chosen AND `node:1` is not already in the features block** (check the pre-flight read — skip this edit if `"ghcr.io/devcontainers/features/node:1"` is already present), replace the current `"features"` block — use the **exact current text** from the pre-flight read as `old_string`, adding the node entry:
   ```json
   "features": {
       "ghcr.io/devcontainers/features/github-cli:1": {},
       "ghcr.io/devcontainers/features/node:1": {}
     },
   ```
   (Match the exact whitespace/indentation of the current file.)
4. Replace the current `"forwardPorts": <CURRENT_VALUE>` with `"forwardPorts": [<comma-separated port integers>]`
   - If no ports selected, use `[]`
5. Replace the current `"extensions": <CURRENT_VALUE>` with `"extensions": [<quoted extension IDs>]`
   - If no extensions selected, use `[]`

**After editing, validate the JSONC syntax** by running:
```bash
node -e "
  const c = require('fs').readFileSync('.devcontainer/devcontainer.json', 'utf8');
  const s = c.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
  try { JSON.parse(s); console.log('OK'); } catch(e) { console.error('INVALID:', e.message); process.exit(1); }
"
```
If this prints `INVALID`, read the file again and fix the malformed JSON before proceeding.

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

**Read the file first**. Make the following targeted Edit calls using the exact current text as `old_string`:

**6a. Project name** — Replace `[Your Project Name]` (or the current name if re-running) with `<PROJECT_NAME>`.

**6b. Overview section** — Replace:
```
<!-- What does this project do? What problem does it solve? -->
```
with the project description:
```
<PROJECT_DESC>
```

**6c. Tech Stack section** — Replace:
```
<!-- e.g. Node.js 22, TypeScript, React, PostgreSQL -->
```
with the chosen stack. Use this map:

| Stack chosen | Tech Stack content |
|---|---|
| Node.js 22 | `Node.js 22, JavaScript / TypeScript` |
| Python 3.12 | `Python 3.12` |
| Go 1.22 | `Go 1.22` |
| Rust | `Rust` |
| Other / custom | the image name the user provided |

**6d. Development commands** — Make three separate Edit calls (build, test, run), one per placeholder line. The exact `old_string` for each is the comment inside the code fence:

| Section | old_string (exact) | new_string for chosen stack |
|---|---|---|
| Build | `# e.g. npm run build` | Node: `npm run build` · Python: `pip install -r requirements.txt` · Go: `go build ./...` · Rust: `cargo build` · Other: `# add build command` |
| Test | `# e.g. npm test` | Node: `npm test` · Python: `pytest` · Go: `go test ./...` · Rust: `cargo test` · Other: `# add test command` |
| Run | `# e.g. npm start` | Node: `npm start` · Python: `python main.py` · Go: `go run main.go` · Rust: `cargo run` · Other: `# add run command` |

Each old_string appears only once in CLAUDE.md, so these replacements are safe. If a replacement fails, re-read the file, find the actual current text, and retry with the correct old_string.

---

## Step 7 — Apply GitHub repo settings

Check if the gh CLI is authenticated: run `gh auth status 2>&1` and inspect the output.

**If authenticated AND a remote origin exists** (check with `git remote get-url origin 2>&1`):

- If user chose "Yes" for GH description:
  ```bash
  gh repo edit --description "<PROJECT_DESC>"
  ```
- For visibility — **always include `--accept-visibility-change-consequences`**, it is required by `gh` whenever `--visibility` is used:
  ```bash
  gh repo edit --visibility public --accept-visibility-change-consequences
  # or
  gh repo edit --visibility private --accept-visibility-change-consequences
  ```

**If not authenticated or no remote:** Skip gh commands and tell the user what to run manually:
```
gh repo edit --description "..." --visibility public --accept-visibility-change-consequences
```

---

## Step 7b — Extend `.gitignore` with stack-specific entries

Check if `.gitignore` exists (`test -f .gitignore`). If it does not exist, create it with at minimum:
```
.claude/*.local.md
.claude/*.local.json
.env
.env.*
!.env.example
*.log
.DS_Store
```

Then append stack-specific entries (only if they are not already present — check with `grep`):

| Stack | Entries to append |
|---|---|
| Node.js 22 | `node_modules/`, `dist/`, `.npm/` |
| Python 3.12 | `__pycache__/`, `*.pyc`, `venv/`, `.venv/`, `*.egg-info/` |
| Go 1.22 | `*.exe`, `*.test`, `coverage.out` |
| Rust | `target/` |
| Other | nothing extra |

Use Bash to append only missing entries, e.g.:
```bash
grep -q "node_modules" .gitignore || printf "\n# Node.js\nnode_modules/\ndist/\n.npm/\n" >> .gitignore
```

---

## Step 8 — Remove `init.sh` if present

```bash
test -f init.sh && rm init.sh && echo "Removed init.sh" || echo "init.sh not present"
```

---

## Step 8b — Verify `setup.sh` is hardened

The template's current `setup.sh` uses non-fatal `|| echo` fallbacks on all `claude` commands and runs three steps: marketplace registration, plugin install, and `claude install`. **Read the file** and check it matches this pattern. If any `claude` command is bare (no `|| ...` fallback), add the fallback. If the marketplace registration or `claude install` steps are missing entirely, add them before/after the plugin install step respectively.

---

## Step 9 — Commit

Stage all changed files:
```bash
git add .devcontainer/devcontainer.json .devcontainer/setup.sh README.md CLAUDE.md .gitignore
git add -u
```

Verify what will be committed with `git status`, then commit using a heredoc so the multi-line message is handled safely:
```bash
git commit -m "$(cat <<'EOF'
Initialise project: <PROJECT_NAME>

Configure devcontainer for <TECH_STACK> (<IMAGE>),
forward ports <PORTS_OR_NONE>, update README and CLAUDE.md.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
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