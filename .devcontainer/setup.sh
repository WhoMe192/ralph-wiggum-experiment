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
elif [ -f "$CLAUDE_JSON_REAL" ]; then
  # Persisted file exists on volume — discard the fresh one created during setup and symlink to it
  rm -f "$CLAUDE_JSON"
  ln -s "$CLAUDE_JSON_REAL" "$CLAUDE_JSON"
  echo "  ✓ Symlinked to existing persisted $CLAUDE_JSON_REAL"
elif [ -f "$CLAUDE_JSON" ]; then
  # No persisted file yet — move the fresh one to the volume and symlink
  mv "$CLAUDE_JSON" "$CLAUDE_JSON_REAL"
  ln -s "$CLAUDE_JSON_REAL" "$CLAUDE_JSON"
  echo "  ✓ Moved and symlinked $CLAUDE_JSON -> $CLAUDE_JSON_REAL"
else
  ln -s "$CLAUDE_JSON_REAL" "$CLAUDE_JSON"
  echo "  ✓ Created symlink $CLAUDE_JSON -> $CLAUDE_JSON_REAL"
fi

echo "==> Marking Claude Code onboarding as complete..."
# The claude commands above create ~/.claude.json. Merge in hasCompletedOnboarding
# so the first-run wizard never appears when the user opens an interactive session.
if [ -f "$CLAUDE_JSON" ]; then
  tmp=$(mktemp)
  jq '. + {"hasCompletedOnboarding": true, "lastOnboardingVersion": "2.1.87"}' "$CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CLAUDE_JSON"
  echo "  ✓ Merged into existing $CLAUDE_JSON"
else
  echo '{"hasCompletedOnboarding": true, "lastOnboardingVersion": "2.1.87", "installMethod": "native", "autoUpdates": false}' > "$CLAUDE_JSON_REAL"
  echo "  ✓ Created $CLAUDE_JSON_REAL"
fi

echo "==> Setup complete. Run 'claude /ralph-loop:help' to get started."
