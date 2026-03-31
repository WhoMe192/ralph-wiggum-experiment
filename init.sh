#!/usr/bin/env bash
# One-time setup script to customise this template for your project.
# Run once after creating a repo from the template, then delete this file.
set -e

echo "🔧 Project Initialisation"
echo "========================="
echo ""

# Prompt for project details
read -rp "Project name (e.g. my-cool-app): " PROJECT_NAME
if [[ -z "$PROJECT_NAME" ]]; then
  echo "Error: project name is required." >&2
  exit 1
fi

read -rp "GitHub owner/org (e.g. myorg): " GITHUB_OWNER
if [[ -z "$GITHUB_OWNER" ]]; then
  echo "Error: GitHub owner is required." >&2
  exit 1
fi

read -rp "Short description: " PROJECT_DESC
PROJECT_DESC="${PROJECT_DESC:-A project using Claude Code}"

REPO="${GITHUB_OWNER}/${PROJECT_NAME}"

# Update devcontainer name
sed -i "s/\"name\": \"Claude Code Dev Environment\"/\"name\": \"${PROJECT_NAME} Dev Environment\"/" .devcontainer/devcontainer.json

# Update README
cat > README.md <<EOF
# ${PROJECT_NAME}

${PROJECT_DESC}

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

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/${REPO})

### Authenticate

On first container start, an auth check runs automatically. Follow any prompts to log in:

- **GitHub CLI:** \`gh auth login\`
- **Claude Code:** \`claude\` (follow the login prompt)
- **Git identity:** set via \`git config\` if not already configured

## Usage

<!-- Add your project-specific usage instructions here -->

## Development

This project uses a devcontainer with Claude Code pre-installed.
See [CLAUDE.md](CLAUDE.md) for project conventions and AI-assisted development guidelines.
EOF

# Update CLAUDE.md project name
sed -i "s/\[Your Project Name\]/${PROJECT_NAME}/" CLAUDE.md

echo ""
echo "✅ Initialised ${REPO}"
echo ""
echo "Next steps:"
echo "  1. Review the updated README.md and CLAUDE.md"
echo "  2. Commit the changes: git add -A && git commit -m 'Initialise project from template'"
echo "  3. Delete this file: rm init.sh"
