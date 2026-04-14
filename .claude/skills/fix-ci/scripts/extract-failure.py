#!/usr/bin/env python3
"""
Extract structured failure information from a Cloud Build log.

Usage:
    uv run python extract-failure.py <build-id>

Writes a JSON file to /tmp/ci-failure-<build-id>.json and prints its path.

JSON fields:
    failing_step           - name of the step that failed
    passing_steps_inline   - comma-separated names of steps that passed
    passing_steps_bullet_list - markdown bullet list (e.g. "- secret-scan ✓")
    error_excerpt          - up to 15 lines of error output from the log
    error_type             - classification: "permission" | "build" | "code" | "unknown"
"""

import json
import re
import subprocess
import sys
from pathlib import Path

import os

REGION = os.environ.get("CLAUDE_GCP_REGION")
PROJECT = os.environ.get("CLAUDE_GCP_PROJECT")
if not REGION or not PROJECT:
    sys.exit("CLAUDE_GCP_REGION and CLAUDE_GCP_PROJECT must be set")

# Lines that add noise without signal (Docker pull output etc.)
NOISE_PATTERN = re.compile(
    r"Pulling|Download|Verifying|fs layer|Waiting|Already exists|"
    r"Pull complete|Digest:|Status:|Sending build context|Step \d+/\d+"
)

# Pattern that identifies a Cloud Build named step
STEP_HEADER = re.compile(r'Step #(\d+) - "([^"]+)":')

# Patterns that signal an error in the log
ERROR_SIGNAL = re.compile(
    r"\bERROR\b|FTL|FAIL(?!\w)|fatal|Failed|npm error|\bfailed\b",
    re.IGNORECASE,
)


def get_log(build_id: str) -> list[str]:
    result = subprocess.run(
        ["gcloud", "builds", "log", build_id, f"--region={REGION}", f"--project={PROJECT}"],
        capture_output=True,
        text=True,
    )
    lines = result.stdout.splitlines()
    # Strip noisy Docker / infrastructure lines
    return [l for l in lines if not NOISE_PATTERN.search(l)]


def parse_steps(lines: list[str]) -> dict[int, str]:
    """Return {step_number: step_name} for every named step seen in the log."""
    steps = {}
    for line in lines:
        m = STEP_HEADER.search(line)
        if m:
            steps[int(m.group(1))] = m.group(2)
    return steps


def find_failing_step(lines: list[str], steps: dict[int, str]) -> tuple[int | None, str]:
    """
    Walk the log top-to-bottom and return the (step_number, step_name) of the
    first step that has error-signal lines attributed to it.

    Strategy: track the most-recently-seen step header; when we hit an error
    signal line, blame it on that step.
    """
    current_step_num: int | None = None
    current_step_name: str = "unknown"

    for line in lines:
        m = STEP_HEADER.search(line)
        if m:
            current_step_num = int(m.group(1))
            current_step_name = m.group(2)
            continue

        if ERROR_SIGNAL.search(line):
            return current_step_num, current_step_name

    # Fallback: last step seen
    if steps:
        last_num = max(steps)
        return last_num, steps[last_num]
    return None, "unknown"


def extract_error_lines(lines: list[str], failing_step_num: int | None) -> list[str]:
    """
    Return up to 15 lines of error output.  If we know the failing step number,
    restrict to lines attributed to that step; otherwise take all error lines.
    """
    in_failing_step = failing_step_num is None  # if unknown, collect from start
    collected: list[str] = []

    for line in lines:
        m = STEP_HEADER.search(line)
        if m:
            num = int(m.group(1))
            in_failing_step = (num == failing_step_num)
            continue

        if in_failing_step and ERROR_SIGNAL.search(line):
            collected.append(line.strip())
            if len(collected) >= 15:
                break

    return collected


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: extract-failure.py <build-id>", file=sys.stderr)
        sys.exit(1)

    build_id = sys.argv[1]

    lines = get_log(build_id)
    if not lines:
        print(f"No log output for build {build_id}", file=sys.stderr)
        sys.exit(1)

    steps = parse_steps(lines)
    failing_num, failing_step = find_failing_step(lines, steps)

    passing_steps = [
        steps[n] for n in sorted(steps) if n != failing_num
    ]

    error_lines = extract_error_lines(lines, failing_num)

    output = {
        "failing_step": failing_step,
        "passing_steps_inline": ", ".join(passing_steps) if passing_steps else "none",
        "passing_steps_bullet_list": "\n".join(f"- {s} ✓" for s in passing_steps),
        "error_excerpt": "\n".join(error_lines) if error_lines else "(no error lines found — check raw log)",
    }

    # Classify error type from excerpt text
    error_text = output["error_excerpt"].upper()
    if any(p in error_text for p in [
        "PERMISSION_DENIED", "403", "IAM", "SECRETMANAGER",
        "ROLES/", "RESOURCE_EXHAUSTED", "QUOTA EXCEEDED"
    ]):
        error_type = "permission"
    elif any(p in error_text for p in ["IMAGE NOT FOUND", "DOCKER", "FAILED TO PULL"]):
        error_type = "build"
    elif any(p in error_text for p in ["NPM ERR", "SYNTAXERROR", "FAIL", "TEST FAILED"]):
        error_type = "code"
    else:
        error_type = "unknown"

    output["error_type"] = error_type

    out_path = Path(f"/tmp/ci-failure-{build_id}.json")
    out_path.write_text(json.dumps(output, indent=2))
    print(str(out_path))


if __name__ == "__main__":
    main()
