#!/bin/bash
# Analyse git diff to understand nature of changes
# Usage: ./analyse-diff.sh [--files file1 file2 ...]
# Returns: JSON with analysis results

set -e

FILES=""
if [ "$1" = "--files" ]; then
  shift
  FILES="$*"
fi

if [ -n "$FILES" ]; then
  DIFF_CONTENT=$(git diff --cached -- $FILES 2>/dev/null || echo "")
  DIFF_NUMSTAT=$(git diff --cached --numstat -- $FILES 2>/dev/null || echo "")
else
  DIFF_CONTENT=$(git diff --cached 2>/dev/null || echo "")
  DIFF_NUMSTAT=$(git diff --cached --numstat 2>/dev/null || echo "")
fi

INSERTIONS=$(echo "$DIFF_NUMSTAT" | awk '{sum+=$1} END {print sum+0}')
DELETIONS=$(echo "$DIFF_NUMSTAT" | awk '{sum+=$2} END {print sum+0}')

detect_pattern() {
  local pattern=$1
  local files
  if [ -n "$FILES" ]; then
    files="$FILES"
  else
    files=$(git diff --cached --name-only 2>/dev/null || echo "")
  fi
  if echo "$files" | grep -q "$pattern"; then echo "true"; else echo "false"; fi
}

HAS_TESTS=$(detect_pattern "test\|spec\|__tests__")
HAS_DOCS=$(detect_pattern "\.md$\|docs/")
HAS_CONFIG=$(detect_pattern "config\|\.json$\|\.yaml$\|\.yml$\|\.toml$")
HAS_CI=$(detect_pattern "\.github/workflows\|cloudbuild\.yaml")
HAS_INFRA=$(detect_pattern "^infra/\|\.tf$")
HAS_ORCHESTRATOR=$(detect_pattern "^orchestrator/")
HAS_DEVCONTAINER=$(detect_pattern "^\.devcontainer/")
HAS_SKILLS=$(detect_pattern "^\.claude/skills/")

detect_code_pattern() {
  local pattern=$1
  if echo "$DIFF_CONTENT" | grep -q "$pattern"; then echo "true"; else echo "false"; fi
}

HAS_NEW_FUNCTIONS=$(detect_code_pattern "^+.*function \|^+.*const .* = \|^+.*def \|^+.*fn ")
HAS_DELETED_FUNCTIONS=$(detect_code_pattern "^-.*function \|^-.*const .* = \|^-.*def \|^-.*fn ")
HAS_NEW_ROUTES=$(detect_code_pattern "^+.*app\.\(get\|post\|put\|delete\|patch\)\|^+.*router\.\(get\|post\|put\|delete\|patch\)")
HAS_ENV_VARS=$(detect_code_pattern "^+.*process\.env\|^+.*env\.\|^-.*process\.env\|^-.*env\.")

suggest_type() {
  if [ "$HAS_DOCS" = "true" ]; then
    local non_docs_files
    if [ -n "$FILES" ]; then
      non_docs_files=$(echo "$FILES" | grep -v "\.md$" | grep -v "^docs/" || echo "")
    else
      non_docs_files=$(git diff --cached --name-only | grep -v "\.md$" | grep -v "^docs/" || echo "")
    fi
    if [ -z "$non_docs_files" ]; then echo "docs"; return; fi
  fi
  if [ "$HAS_TESTS" = "true" ]; then
    local non_test_files
    non_test_files=$(git diff --cached --name-only | grep -v "test\|spec" || echo "")
    if [ -z "$non_test_files" ]; then echo "test"; return; fi
  fi
  if [ "$HAS_CI" = "true" ]; then echo "ci"; return; fi
  if [ "$HAS_INFRA" = "true" ] && [ "$HAS_ORCHESTRATOR" = "false" ]; then echo "infra"; return; fi
  if [ "$HAS_SKILLS" = "true" ]; then echo "chore"; return; fi
  if [ "$HAS_NEW_FUNCTIONS" = "true" ] && [ "$INSERTIONS" -gt "$DELETIONS" ]; then echo "feat"; return; fi
  if [ "$HAS_DELETED_FUNCTIONS" = "true" ]; then echo "refactor"; return; fi
  if [ "$DELETIONS" -gt "$INSERTIONS" ]; then echo "refactor"; return; fi
  echo "fix"
}

suggest_scope() {
  local files
  if [ -n "$FILES" ]; then files="$FILES"; else files=$(git diff --cached --name-only 2>/dev/null || echo ""); fi

  if echo "$files" | grep -q "^<e2e-test-dir>/"; then echo "e2e"
  elif echo "$files" | grep -q "^orchestrator/"; then echo "orchestrator"
  elif echo "$files" | grep -q "^infra/"; then echo "infra"
  elif echo "$files" | grep -q "^docs/"; then echo "docs"
  elif echo "$files" | grep -q "^\.devcontainer/"; then echo "devcontainer"
  elif echo "$files" | grep -q "^\.claude/skills/"; then echo "skills"
  else echo ""
  fi
}

SUGGESTED_TYPE=$(suggest_type)
SUGGESTED_SCOPE=$(suggest_scope)

if [ "$INSERTIONS" -gt 500 ] || [ "$DELETIONS" -gt 500 ]; then
  MAGNITUDE="large"
elif [ "$INSERTIONS" -gt 100 ] || [ "$DELETIONS" -gt 100 ]; then
  MAGNITUDE="medium"
else
  MAGNITUDE="small"
fi

cat <<EOF
{
  "statistics": {
    "insertions": $INSERTIONS,
    "deletions": $DELETIONS,
    "net_change": $((INSERTIONS - DELETIONS)),
    "magnitude": "$MAGNITUDE"
  },
  "patterns": {
    "has_tests": $HAS_TESTS,
    "has_docs": $HAS_DOCS,
    "has_config": $HAS_CONFIG,
    "has_ci": $HAS_CI,
    "has_infra": $HAS_INFRA,
    "has_orchestrator": $HAS_ORCHESTRATOR,
    "has_devcontainer": $HAS_DEVCONTAINER,
    "has_skills": $HAS_SKILLS,
    "has_new_functions": $HAS_NEW_FUNCTIONS,
    "has_deleted_functions": $HAS_DELETED_FUNCTIONS,
    "has_new_routes": $HAS_NEW_ROUTES,
    "has_env_vars": $HAS_ENV_VARS
  },
  "suggestions": {
    "type": "$SUGGESTED_TYPE",
    "scope": "$SUGGESTED_SCOPE"
  }
}
EOF
