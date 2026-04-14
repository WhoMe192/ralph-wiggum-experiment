#!/usr/bin/env python3
"""Compare newly added corpus entries against existing exemplar scores.

For each newly added phase, queries the JSONL corpus to find the current
per-dimension maximum scores for the same phase type (excluding the new
entries), then reports any dimensions where the new phase outscores the
existing best — surfacing potential exemplar improvement candidates.

Usage:
    uv run python compare-exemplars.py <new_ids_csv> <new_scores_json>

Arguments:
    new_ids_csv      Comma-separated phase_ids just added, e.g. "27,29"
    new_scores_json  JSON array of {phase_id, type, review_scores} objects

Output (stdout):
    One line per new phase reporting outscored dimensions or "no dimensions outscored".

Exit codes:
    0  Comparison complete
    1  Error (missing JSONL, bad arguments, etc.)

Example:
    uv run python compare-exemplars.py "27" \
      '[{"phase_id":"27","type":"harness","review_scores":{"C":2,"S":2,"D":2,"B":1,"K":2,"V":2,"P":2,"T":2,"Z":2,"CL":1}}]'
"""

import json
import sys
from pathlib import Path

JSONL_PATH = Path("prompts/phase-corpus.jsonl")
DIMS = ["C", "S", "D", "B", "K", "V", "P", "T", "Z", "CL"]


def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: compare-exemplars.py <new_ids_csv> <new_scores_json>", file=sys.stderr)
        sys.exit(1)

    new_ids = [x.strip() for x in sys.argv[1].split(",") if x.strip()]
    new_entries = json.loads(sys.argv[2])

    if not JSONL_PATH.exists():
        print(f"ERROR: {JSONL_PATH} not found — run migrate-corpus.py first", file=sys.stderr)
        sys.exit(1)

    try:
        import duckdb
    except ImportError:
        print("ERROR: duckdb not available — run 'uv add duckdb'", file=sys.stderr)
        sys.exit(1)

    # Build per-type max scores from existing corpus, excluding new entries
    exclude = ", ".join(f"'{i}'" for i in new_ids)
    sql = f"""
        SELECT
            type,
            MAX(CAST(review_scores->>'C'  AS INT)) AS maxC,
            MAX(CAST(review_scores->>'S'  AS INT)) AS maxS,
            MAX(CAST(review_scores->>'D'  AS INT)) AS maxD,
            MAX(CAST(review_scores->>'B'  AS INT)) AS maxB,
            MAX(CAST(review_scores->>'K'  AS INT)) AS maxK,
            MAX(CAST(review_scores->>'V'  AS INT)) AS maxV,
            MAX(CAST(review_scores->>'P'  AS INT)) AS maxP,
            MAX(CAST(review_scores->>'T'  AS INT)) AS maxT,
            MAX(CAST(review_scores->>'Z'  AS INT)) AS maxZ,
            MAX(CAST(review_scores->>'CL' AS INT)) AS maxCL
        FROM read_json('{JSONL_PATH}')
        WHERE phase_id NOT IN ({exclude})
        GROUP BY type
    """
    rows = duckdb.sql(sql).fetchall()
    by_type: dict[str, dict[str, int]] = {
        row[0]: dict(zip(DIMS, row[1:])) for row in rows
    }

    for entry in new_entries:
        phase_id = entry["phase_id"]
        phase_type = entry["type"]
        scores = entry.get("review_scores", {})
        maxes = by_type.get(phase_type, {d: 0 for d in DIMS})

        better = [d for d in DIMS if (scores.get(d) or 0) > (maxes.get(d) or 0)]
        if better:
            print(
                f"Phase {phase_id} ({phase_type}) outscores current best on: "
                + ", ".join(better)
            )
        else:
            print(f"Phase {phase_id} ({phase_type}) — no dimensions outscored")


if __name__ == "__main__":
    main()
