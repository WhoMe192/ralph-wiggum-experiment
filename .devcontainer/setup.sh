#!/usr/bin/env bash
set -e

echo "==> Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

echo "==> Adding official Claude plugins marketplace..."
claude --print /plugin marketplace add anthropics/claude-plugins-official \
  || echo "Warning: marketplace registration failed — run manually: claude /plugin marketplace add anthropics/claude-plugins-official"

echo "==> Installing ralph-loop plugin..."
claude --print /plugin install ralph-loop \
  || echo "Warning: ralph-loop plugin install failed — run manually: claude /plugin install ralph-loop"

echo "==> Running claude install..."
claude install \
  || echo "Warning: claude install failed — run manually: claude install"

echo "==> Setup complete. Run 'claude /ralph-loop:help' to get started."
