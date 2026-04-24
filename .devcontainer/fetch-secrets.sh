#!/usr/bin/env bash
# Runs on the host before container start.
# Fetches secrets from macOS Keychain into .devcontainer/.env for container injection.
#
# Keychain service names are generic (no per-repo prefix) so a single host-side
# credential store is reused across every ralph-based project.
#
# Claude Code auth — OAuth token preferred (subscription billing),
# API key is the pay-per-token fallback. Store one or both:
#   security add-generic-password -a "$USER" -s "CLAUDE_OAUTH_TOKEN"   -w "sk-ant-oat01-..."
#   security add-generic-password -a "$USER" -s "ANTHROPIC_API_KEY"    -w "sk-ant-..."
#
# Optional secrets:
#   security add-generic-password -a "$USER" -s "GITHUB_TOKEN"      -w "ghp_..."
#   security add-generic-password -a "$USER" -s "GIT_AUTHOR_NAME"   -w "Your Name"
#   security add-generic-password -a "$USER" -s "GIT_AUTHOR_EMAIL"  -w "you@example.com"
set -e

echo "==> Fetching secrets from Keychain..."

: > .devcontainer/.env

CLAUDE_CODE_OAUTH_TOKEN=$(security find-generic-password -a "$USER" -s "CLAUDE_OAUTH_TOKEN" -w 2>/dev/null) || true
ANTHROPIC_API_KEY=$(security find-generic-password -a "$USER" -s "ANTHROPIC_API_KEY" -w 2>/dev/null) || true

if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
  echo "CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN}" >> .devcontainer/.env
  echo "  ✓ CLAUDE_CODE_OAUTH_TOKEN written (subscription billing)"
fi

if [ -n "$ANTHROPIC_API_KEY" ]; then
  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" >> .devcontainer/.env
  echo "  ✓ ANTHROPIC_API_KEY written (pay-per-token fallback)"
fi

if [ -z "$CLAUDE_CODE_OAUTH_TOKEN" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "  ✗ No Claude credential found in Keychain"
  echo "    Store one (OAuth preferred):"
  echo "      security add-generic-password -a \"\$USER\" -s \"CLAUDE_OAUTH_TOKEN\" -w \"sk-ant-oat01-...\""
  echo "      security add-generic-password -a \"\$USER\" -s \"ANTHROPIC_API_KEY\"  -w \"sk-ant-...\""
  exit 1
fi

# Optional: GitHub token
GITHUB_TOKEN=$(security find-generic-password -a "$USER" -s "GITHUB_TOKEN" -w 2>/dev/null) || true
if [ -n "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN=${GITHUB_TOKEN}" >> .devcontainer/.env
  echo "  ✓ GITHUB_TOKEN written"
fi

# Optional: Git identity (pre-configures git inside the container)
GIT_AUTHOR_NAME=$(security find-generic-password -a "$USER" -s "GIT_AUTHOR_NAME" -w 2>/dev/null) || true
GIT_AUTHOR_EMAIL=$(security find-generic-password -a "$USER" -s "GIT_AUTHOR_EMAIL" -w 2>/dev/null) || true
if [ -n "$GIT_AUTHOR_NAME" ]; then
  echo "GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME}" >> .devcontainer/.env
  echo "GIT_COMMITTER_NAME=${GIT_AUTHOR_NAME}" >> .devcontainer/.env
  echo "  ✓ GIT_AUTHOR_NAME written"
fi
if [ -n "$GIT_AUTHOR_EMAIL" ]; then
  echo "GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL}" >> .devcontainer/.env
  echo "GIT_COMMITTER_EMAIL=${GIT_AUTHOR_EMAIL}" >> .devcontainer/.env
  echo "  ✓ GIT_AUTHOR_EMAIL written"
fi

echo "  ✓ Secrets written to .devcontainer/.env"
