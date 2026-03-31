# Claude Code + Ralph-Wiggum Devcontainer Template

A ready-to-go devcontainer template with [Claude Code](https://claude.ai/claude-code)
and the [Ralph-Wiggum](https://awesomeclaude.ai/ralph-wiggum) iterative loop plugin
pre-installed. Clone it, run `init.sh`, and start building with AI-assisted development.

## Quick Start

### 1. Create your repo from this template

Click **"Use this template"** on GitHub, or:

```bash
gh repo create my-project --template WhoMe192/ralph-wiggum-experiment --clone
cd my-project
```

### 2. Open in a devcontainer

- **VS Code:** Open the folder → click **Reopen in Container** when prompted
- **Codespaces:** [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/WhoMe192/ralph-wiggum-experiment)

The container automatically installs Claude Code CLI, the ralph-loop plugin, and GitHub CLI.

### 3. Initialise your project

Inside Claude Code, run:

```
/init-project
```

This interactive skill asks you for your project name, GitHub owner, description, and tech stack, then:
- Configures the devcontainer with the right base image, ports, and VS Code extensions
- Rewrites README.md and updates CLAUDE.md with your project details
- Sets your GitHub repo description and visibility
- Commits everything in one go

Alternatively, run the bash script directly:

```bash
./init.sh
```

### 4. Authenticate

An auth check runs on every container start. Follow any prompts:

```
gh auth login          # GitHub CLI
claude                 # Claude Code — follow the login prompt
claude install         # Install recommendation from Claude 
```

## What's Included

| Component | Purpose |
|-----------|---------|
| Claude Code CLI | AI-assisted development from the terminal |
| Ralph-Loop plugin | [Ralph-Wiggum](https://awesomeclaude.ai/ralph-wiggum) iterative loop methodology |
| GitHub CLI (`gh`) | Repo, PR, and issue management |
| Auth check script | Reminds you to log in on container start |
| `init.sh` | One-time project customisation |
| `CLAUDE.md` | Starter project conventions for Claude |

## Customising the Tech Stack

Edit `.devcontainer/devcontainer.json` to change:

- **Base image** — swap `javascript-node:22` for Python, Go, Rust, etc. (options listed in comments)
- **Forwarded ports** — add ports your app needs
- **VS Code extensions** — add language-specific extensions

## Using Ralph-Wiggum

Once authenticated, start a loop:

```bash
claude /ralph-loop:ralph-loop "<your prompt>" \
  --max-iterations 10 \
  --completion-promise "DONE"
```

Other commands: `/ralph-loop:cancel-ralph` (stop a loop), `/ralph-loop:help` (usage info).

## Project Setup Skill

| Command | Purpose |
|---------|---------|
| `/init-project` | Interactive setup — configures devcontainer, README, CLAUDE.md, GitHub repo metadata, and commits |

## References

- [Ralph-Wiggum methodology](https://awesomeclaude.ai/ralph-wiggum)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Dev Containers specification](https://containers.dev/)
