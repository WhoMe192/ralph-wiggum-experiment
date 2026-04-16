#!/usr/bin/env bash
# Platform pre-flight checks (P1–P6) for a Claude Code skill.
#
# Source: docs/skill-design-standards.md §Platform Structure Requirements.
#
# Usage: preflight-check.sh <skill-name>
#   skill-name  Required. Matches a directory under .claude/skills/
#
# Stdout: JSON object with per-check results and an overall status field.
# Stderr: progress messages.
# Exit codes: 0=all checks passed, 1=one or more FAILs, 2=invalid args / skill not found.

set -euo pipefail

SKILL_NAME="${1:?Usage: preflight-check.sh <skill-name>}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL_DIR="$REPO_ROOT/.claude/skills/$SKILL_NAME"
SKILL_FILE="$SKILL_DIR/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  echo "Skill not found at $SKILL_FILE" >&2
  exit 2
fi

fails=0

# --- P1: line count ≤ 500 -----------------------------------------------------
p1_lines=$(wc -l < "$SKILL_FILE" | tr -d ' ')
if [ "$p1_lines" -le 500 ]; then p1_status="PASS"; else p1_status="FAIL"; fails=$((fails+1)); fi

# --- frontmatter block --------------------------------------------------------
# Grab lines between the first two `---` markers.
fm=$(awk '/^---$/{c++; next} c==1{print}' "$SKILL_FILE")

get_fm() {
  # $1 = key. Prints the raw value (everything after "key:"), trimmed.
  printf '%s\n' "$fm" | awk -v k="$1:" '
    $0 ~ "^"k { sub("^"k"[[:space:]]*", ""); print; exit }
  '
}

# --- P2: description ≤ 250 chars ---------------------------------------------
# description can be either a block scalar (`description: >` then indented lines)
# or an inline value.
desc_raw=$(printf '%s\n' "$fm" | awk '
  /^description:[[:space:]]*>/ { block=1; next }
  block==1 && /^[[:space:]]+/ { sub(/^[[:space:]]+/,""); printf "%s ", $0; next }
  block==1 { exit }
  /^description:/ { sub(/^description:[[:space:]]*/,""); print; exit }
')
desc=$(printf '%s' "$desc_raw" | sed 's/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
p2_chars=${#desc}
if [ "$p2_chars" -le 250 ]; then p2_status="PASS"; else p2_status="FAIL"; fails=$((fails+1)); fi

# --- P3: name lowercase, digits, hyphens; ≤64 chars --------------------------
name_val=$(get_fm name | sed 's/^"\(.*\)"$/\1/')
if [ -z "$name_val" ]; then
  # defaults to directory name per platform docs
  name_val="$SKILL_NAME"
fi
p3_name_len=${#name_val}
if [[ "$name_val" =~ ^[a-z0-9-]+$ ]] && [ "$p3_name_len" -le 64 ]; then
  p3_status="PASS"
else
  p3_status="FAIL"; fails=$((fails+1))
fi

# --- P4: invocation control -------------------------------------------------
# Heuristic: if description contains side-effect verbs and disable-model-invocation
# is not set to true, flag as WARN. Claude makes the final call.
dmi_val=$(get_fm disable-model-invocation | tr -d '"[:space:]')
side_effect_matches=$(printf '%s' "$desc" | grep -oiE '\b(commit|push|deploy|apply|post|send|write|edit|create|close|tag|release|publish|merge)\b' | sort -u | paste -sd "," - || true)
if [ -z "$side_effect_matches" ]; then
  p4_status="PASS"
  p4_reason="no side-effect verbs detected in description"
elif [ "$dmi_val" = "true" ]; then
  p4_status="PASS"
  p4_reason="side-effect verbs present; disable-model-invocation=true"
else
  p4_status="WARN"
  p4_reason="side-effect verbs (${side_effect_matches}) detected; disable-model-invocation is not true"
fi

# --- P5: $ARGUMENTS fitness -------------------------------------------------
args_present=$(grep -c '\$ARGUMENTS' "$SKILL_FILE" || true)
arg_hint=$(get_fm argument-hint | sed 's/^"\(.*\)"$/\1/')
if [ "$args_present" -eq 0 ]; then
  p5_status="PASS"
  p5_reason="no \$ARGUMENTS usage — argument-hint not required"
elif [ -n "$arg_hint" ]; then
  p5_status="PASS"
  p5_reason="\$ARGUMENTS used; argument-hint present"
else
  p5_status="FAIL"; fails=$((fails+1))
  p5_reason="\$ARGUMENTS used but argument-hint absent from frontmatter"
fi

# --- P6: supporting files referenced ---------------------------------------
unreferenced=""
while IFS= read -r f; do
  base=$(basename "$f")
  [ "$base" = "SKILL.md" ] && continue
  # Look for filename (basename or relative path) anywhere in SKILL.md.
  if ! grep -qF "$base" "$SKILL_FILE"; then
    unreferenced="${unreferenced}${base},"
  fi
done < <(find "$SKILL_DIR" -maxdepth 2 -type f ! -path '*/scripts/__pycache__/*')

unreferenced=${unreferenced%,}
if [ -z "$unreferenced" ]; then
  p6_status="PASS"
  p6_reason="all sibling files referenced from SKILL.md (or none present)"
else
  p6_status="FAIL"; fails=$((fails+1))
  p6_reason="files not referenced: $unreferenced"
fi

# --- overall --------------------------------------------------------------
if [ "$fails" -eq 0 ]; then overall="PASS"; else overall="FAIL"; fi

# JSON emit (hand-rolled to avoid jq dependency)
cat <<JSON
{
  "skill": "$SKILL_NAME",
  "overall": "$overall",
  "fails": $fails,
  "checks": {
    "P1_line_count":     {"status": "$p1_status", "value": $p1_lines, "limit": 500},
    "P2_description_len":{"status": "$p2_status", "value": $p2_chars, "limit": 250},
    "P3_name_field":     {"status": "$p3_status", "value": "$name_val", "limit": "lowercase+digits+hyphens, ≤64"},
    "P4_invocation":     {"status": "$p4_status", "disable_model_invocation": "$dmi_val", "reason": "$p4_reason"},
    "P5_arguments_hint": {"status": "$p5_status", "reason": "$p5_reason"},
    "P6_supporting_files":{"status": "$p6_status", "reason": "$p6_reason"}
  }
}
JSON

[ "$fails" -eq 0 ] && exit 0 || exit 1
