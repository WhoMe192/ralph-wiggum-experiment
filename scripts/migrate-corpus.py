#!/usr/bin/env python3
"""Migrate prompts/phase-corpus.yaml → prompts/phase-corpus.jsonl.

Each phase entry from the YAML phases list becomes one JSON line.
review_total is computed from review_scores if not already present.
"""

import json
from pathlib import Path

import yaml

YAML_PATH = Path("prompts/phase-corpus.yaml")
JSONL_PATH = Path("prompts/phase-corpus.jsonl")


def compute_total(scores: dict) -> int:
    return sum(scores.values()) if scores else 0


def main() -> None:
    data = yaml.safe_load(YAML_PATH.read_text(encoding="utf-8"))
    phases = data.get("phases", [])

    lines = []
    for entry in phases:
        scores = entry.get("review_scores", {})
        if "review_total" not in entry:
            entry["review_total"] = compute_total(scores)
        lines.append(json.dumps(entry, ensure_ascii=False))

    JSONL_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(lines)} entries to {JSONL_PATH}")


if __name__ == "__main__":
    main()
