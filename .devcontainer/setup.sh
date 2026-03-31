#!/usr/bin/env bash
set -e

echo "==> Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

echo "==> Installing ralph-loop plugin..."
claude --print /plugin install ralph-loop@claude-plugins-official

echo "==> Setup complete. Run 'claude /ralph-loop:help' to get started."
