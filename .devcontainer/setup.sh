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

echo "==> Symlinking ~/.claude.json into the persistent volume..."
CLAUDE_JSON_REAL=/home/node/.claude/claude-code/claude.json
CLAUDE_JSON=/home/node/.claude.json
mkdir -p /home/node/.claude/claude-code

if [ -L "$CLAUDE_JSON" ]; then
  echo "  ✓ Symlink already exists, skipping"
else
  # Back up the file created during setup, seed the volume copy if not already there
  [ -f "$CLAUDE_JSON" ] && mv "$CLAUDE_JSON" "${CLAUDE_JSON}.orig"
  [ ! -f "$CLAUDE_JSON_REAL" ] && [ -f "${CLAUDE_JSON}.orig" ] && cp "${CLAUDE_JSON}.orig" "$CLAUDE_JSON_REAL"
  ln -s "$CLAUDE_JSON_REAL" "$CLAUDE_JSON"
  echo "  ✓ Symlinked $CLAUDE_JSON -> $CLAUDE_JSON_REAL"
fi

echo "==> Setup complete. Run 'claude /ralph-loop:help' to get started."
