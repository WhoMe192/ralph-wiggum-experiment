#!/usr/bin/env bash
# Runs on the host before container start.
# Fetches secrets from macOS Keychain into .devcontainer/.env for container injection.
#
# To store your API key in the Keychain, run once on your Mac:
#   security add-generic-password -a "$USER" -s "RALPH_WIGGUM_ANTHROPIC_API_KEY" -w "sk-ant-..."
set -e

echo "==> Fetching secrets from Keychain..."

ANTHROPIC_API_KEY=$(security find-generic-password -a "$USER" -s "RALPH_WIGGUM_ANTHROPIC_API_KEY" -w 2>/dev/null) || {
  echo "  ✗ RALPH_WIGGUM_ANTHROPIC_API_KEY not found in Keychain"
  echo "    Run: security add-generic-password -a \"\$USER\" -s \"RALPH_WIGGUM_ANTHROPIC_API_KEY\" -w \"sk-ant-...\""
  exit 1
}

echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" > .devcontainer/.env
echo "  ✓ Secrets written to .devcontainer/.env"
