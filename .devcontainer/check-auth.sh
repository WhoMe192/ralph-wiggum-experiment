#!/usr/bin/env bash
# Runs on every container start to remind the user about missing auth.

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Checking authentication status..."
echo "══════════════════════════════════════════════════════"

# GitHub CLI
if gh auth status &>/dev/null; then
  echo "  ✓ GitHub CLI — authenticated"
else
  echo "  ✗ GitHub CLI — not authenticated"
  echo "    Run:  gh auth login"
fi

# Claude Code
if [ -n "$ANTHROPIC_API_KEY" ]; then
  echo "  ✓ Claude Code — API key present"
elif claude auth status &>/dev/null; then
  echo "  ✓ Claude Code — authenticated (OAuth)"
else
  echo "  ✗ Claude Code — not authenticated and ANTHROPIC_API_KEY not set"
  echo "    Run:  claude    (then follow the login prompt)"
fi

# Git identity
if git config user.email &>/dev/null; then
  echo "  ✓ Git identity — $(git config user.name) <$(git config user.email)>"
else
  echo "  ✗ Git identity — not configured"
  echo "    Run:  git config --global user.name \"Your Name\""
  echo "          git config --global user.email \"you@example.com\""
fi

echo "══════════════════════════════════════════════════════"
echo ""
