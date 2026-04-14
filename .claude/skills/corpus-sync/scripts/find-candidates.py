#!/usr/bin/env python3
"""Find completed phases missing from the phase corpus.

Reads prompts/phases.yaml and prompts/phase-corpus.yaml, then outputs a JSON
array of phases that are completed, have a prompt directory, and are not yet
in the corpus.

Usage:
    uv run python find-candidates.py [phase_id]

Arguments:
    phase_id  Optional. If given, only that phase is checked.

Output (stdout):
    JSON array of {id, name, directory} objects — one per candidate.
    Empty array [] if corpus is current.

Exit codes:
    0  Candidates found (or none — check output length)
    1  Error reading input files
"""

import json
import re
import sys
from pathlib import Path

import yaml

PHASES_PATH = Path("prompts/phases.yaml")
CORPUS_PATH = Path("prompts/phase-corpus.yaml")


def main() -> None:
    filter_id = sys.argv[1] if len(sys.argv) > 1 else None

    if not PHASES_PATH.exists():
        print(f"ERROR: {PHASES_PATH} not found", file=sys.stderr)
        sys.exit(1)

    phases_data = yaml.safe_load(PHASES_PATH.read_text())

    # Extract existing corpus phase_ids without loading full 1300+ line YAML
    corpus_ids: set[str] = set()
    if CORPUS_PATH.exists():
        for line in CORPUS_PATH.read_text().splitlines():
            m = re.match(r'\s+- phase_id:\s+"?([^"]+)"?', line)
            if m:
                corpus_ids.add(m.group(1))

    candidates = []
    for phase in phases_data.get("phases", []):
        if phase.get("status") != "completed":
            continue
        if phase.get("corpus_entry", False):
            continue
        if not phase.get("directory"):
            continue
        if filter_id and phase["id"] != filter_id:
            continue
        if phase["id"] in corpus_ids:
            continue
        candidates.append({
            "id": phase["id"],
            "name": phase["name"],
            "directory": phase["directory"],
        })

    print(json.dumps(candidates))


if __name__ == "__main__":
    main()
