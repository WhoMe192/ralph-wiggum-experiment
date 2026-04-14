#!/usr/bin/env python3
"""
Fill the CI fix prompt template with build failure details and write a timestamped file.

Usage:
    uv run python generate-prompt.py \\
        --failure-json /tmp/ci-failure-<build-id>.json \\
        --branch <branch> \\
        --build-id <build-id> \\
        --template prompts/ci-fixes/TEMPLATE.md \\
        --output-dir prompts/ci-fixes

Prints the path of the generated file to stdout.
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path


PLACEHOLDERS = {
    "{{BRANCH}}":                  "branch",
    "{{BUILD_ID}}":                "build_id",
    "{{FAILING_STEP}}":            "failing_step",
    "{{PASSING_STEPS_INLINE}}":    "passing_steps_inline",
    "{{PASSING_STEPS_BULLET_LIST}}": "passing_steps_bullet_list",
    "{{ERROR_EXCERPT}}":           "error_excerpt",
}


def branch_slug(branch: str) -> str:
    """Convert a branch name to a filesystem-safe slug."""
    return re.sub(r"[^a-z0-9]+", "-", branch.lower()).strip("-")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--failure-json", required=True, help="Path to ci-failure-<id>.json")
    parser.add_argument("--branch",       required=True)
    parser.add_argument("--build-id",     required=True)
    parser.add_argument("--template",     required=True, help="Path to TEMPLATE.md")
    parser.add_argument("--output-dir",   required=True, help="Directory to write the prompt file")
    args = parser.parse_args()

    # Load failure data
    failure_path = Path(args.failure_json)
    if not failure_path.exists():
        print(f"Error: failure JSON not found: {failure_path}", file=sys.stderr)
        sys.exit(1)
    failure = json.loads(failure_path.read_text())

    # Load template
    template_path = Path(args.template)
    if not template_path.exists():
        print(f"Error: template not found: {template_path}", file=sys.stderr)
        sys.exit(1)
    content = template_path.read_text()

    # Build substitution map
    values = {
        "branch":                    args.branch,
        "build_id":                  args.build_id,
        "failing_step":              failure.get("failing_step", "unknown"),
        "passing_steps_inline":      failure.get("passing_steps_inline", "none"),
        "passing_steps_bullet_list": failure.get("passing_steps_bullet_list", ""),
        "error_excerpt":             failure.get("error_excerpt", "(no error excerpt available)"),
    }

    # Substitute all placeholders
    for placeholder, key in PLACEHOLDERS.items():
        content = content.replace(placeholder, values[key])

    # Check for any remaining unfilled placeholders
    remaining = re.findall(r"\{\{[A-Z_]+\}\}", content)
    if remaining:
        print(f"Warning: unfilled placeholders remain: {remaining}", file=sys.stderr)

    # Write output
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    filename = f"{timestamp}-{branch_slug(args.branch)}.md"
    output_path = Path(args.output_dir) / filename
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(content)

    print(str(output_path))


if __name__ == "__main__":
    main()
