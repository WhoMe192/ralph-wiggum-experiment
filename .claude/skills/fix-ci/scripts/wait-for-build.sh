#!/usr/bin/env bash
# Polls a Cloud Build job until it reaches a terminal state.
#
# Usage: wait-for-build.sh <build-id> [max-minutes]
#   build-id     Required. Cloud Build job ID.
#   max-minutes  Optional. Stop polling after this many minutes (default: 15).
#
# Stdout: the final status string (SUCCESS, FAILURE, TIMEOUT, CANCELLED, etc.)
# Stderr: progress messages
# Exit codes: 0=SUCCESS, 1=FAILURE/TIMEOUT/CANCELLED, 2=polling-timeout

set -euo pipefail

BUILD_ID="${1:?Usage: wait-for-build.sh <build-id> [max-minutes]}"
MAX_MINUTES="${2:-15}"
REGION="${CLAUDE_GCP_REGION:?CLAUDE_GCP_REGION must be set (e.g. europe-west1)}"
PROJECT="${CLAUDE_GCP_PROJECT:?CLAUDE_GCP_PROJECT must be set}"

MAX_POLLS=$(( MAX_MINUTES * 2 ))  # poll every 30 s

echo "Waiting for build ${BUILD_ID} (max ${MAX_MINUTES}m)..." >&2

for i in $(seq 1 "$MAX_POLLS"); do
  STATUS=$(gcloud builds describe "$BUILD_ID" \
    --region="$REGION" \
    --project="$PROJECT" \
    --format="value(status)" 2>/dev/null || echo "UNKNOWN")

  case "$STATUS" in
    SUCCESS)
      echo "SUCCESS"
      exit 0
      ;;
    FAILURE|TIMEOUT|CANCELLED|INTERNAL_ERROR|EXPIRED)
      echo "$STATUS"
      exit 1
      ;;
    WORKING|QUEUED|PENDING)
      echo "  [${i}/${MAX_POLLS}] ${STATUS} — waiting 30s..." >&2
      sleep 30
      ;;
    *)
      echo "  [${i}/${MAX_POLLS}] Unknown status '${STATUS}' — waiting 30s..." >&2
      sleep 30
      ;;
  esac
done

echo "Polling timed out after ${MAX_MINUTES} minutes." >&2
echo "POLLING_TIMEOUT"
exit 2
