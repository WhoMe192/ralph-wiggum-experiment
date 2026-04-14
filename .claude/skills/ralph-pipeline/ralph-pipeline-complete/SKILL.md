---
name: ralph-pipeline-complete
description: >
  Pipeline completion sub-skill for ralph-pipeline. Handles Steps 3a–3j: state cleanup,
  registry update, CI trigger, GitHub issue updates, harness bug filing, concerns filing,
  run record, final commit, trailing cleanup, and pipeline report.
user-invocable: false
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Skill
---

# Ralph Pipeline Complete

This sub-skill executes the pipeline completion sequence (Steps 3a–3j). It is invoked
by the main ralph-pipeline skill via the Read-and-execute pattern.

### 3a. Clean up ralph-loop state

Check whether `~/.ralph/loop-state.md` still exists:

```bash
test -f ~/.ralph/loop-state.md && echo "EXISTS" || echo "ABSENT"
```

If it exists, invoke the cancel skill to clean it up:

```
skill: cancel-ralph
```

### 3b. Update registry

**Update registry status to `completed`:** In `prompts/phases.yaml`, find the matching entry
and set `status: completed` and `completed: <today's date YYYY-MM-DD>`.

### 3c. Trigger CI if application code changed

Check whether any `orchestrator/` files were modified during this pipeline run:

```bash
git diff --name-only $START_SHA HEAD | grep "^orchestrator/" | head -1
```

**If the output is non-empty** (app code was modified):

1. Ensure the branch is pushed so Cloud Build can detect the latest commit:
   ```bash
   git push origin HEAD
   ```

2. Push a `ci-*` tag to trigger the CI gate build:
   ```bash
   SHORT_SHA=$(git rev-parse --short HEAD)
   git tag ci-${SHORT_SHA}
   git push origin ci-${SHORT_SHA}
   ```

3. Invoke the fix-ci skill to monitor the CI gate build and auto-fix any failures:
   ```
   skill: fix-ci
   args: "--env=dev --filter=tags:ci-${SHORT_SHA}"
   ```
   The skill will find the most recent build matching the `ci-${SHORT_SHA}` tag, wait for it to complete,
   and if it fails: create a GitHub issue, generate a fix prompt, and run a ralph-loop
   (max 5 iterations) to diagnose and fix the failure. It closes the issue when CI is green.

**If the output is empty** (infra, harness, or docs-only changes): skip silently.
Note in the Step 3j report that CI was not triggered (no app code changes).

### 3c-uat. Monitor UAT deployment

**Precondition:** only run if Step 3c was executed (orchestrator files changed). Skip silently otherwise.

After Dev CI is confirmed green, find and wait for the UAT build:

**1. Find the UAT build** (poll up to 4 times at 30-second intervals):
```bash
# $COMMIT_SHA is the full SHA — matches --sha=$COMMIT_SHA passed by cloudbuild-pr.yaml trigger-uat step
# Look up UAT trigger ID — filter by trigger_id works for direct-invocation builds (no tag attached)
UAT_TRIGGER_ID=$(gcloud builds triggers describe "${CLAUDE_UAT_TRIGGER:?set CLAUDE_UAT_TRIGGER}" \
  --region="$CLAUDE_GCP_REGION" --project="$CLAUDE_GCP_PROJECT" \
  --format='value(id)')
UAT_BUILD_ID=$(gcloud builds list \
  --region="$CLAUDE_GCP_REGION" \
  --project="$CLAUDE_GCP_PROJECT" \
  --filter="trigger_id=$UAT_TRIGGER_ID AND substitutions.COMMIT_SHA=$COMMIT_SHA" \
  --limit=1 \
  --sort-by="~createTime" \
  --format="value(id)")
```
**If no build found after 4 polls:**
Append to `<phase-dir>/harness-bugs.md`:

## Bug — UAT build not found after Dev CI — Step 3c-uat

**Where:** Step 3c-uat — UAT deployment monitoring
**What happened:** Polled 4 times at 30-second intervals for a uat-* Cloud Build; none found.
  Dev CI build was: <DEV_BUILD_ID>. This may mean the ci-* tag push was skipped or the
  UAT trigger is not wired correctly.
**Root cause:** UAT trigger is invoked directly via `gcloud builds triggers run` — these builds
  carry no git tags, so the previous tag-based filter never matched.
**Suggested fix:** Verify the `trigger_id` filter in Step 3c-uat uses the correct trigger ID
  for `"${CLAUDE_UAT_TRIGGER:?set CLAUDE_UAT_TRIGGER}"`, and that `cloudbuild-pr.yaml` step `trigger-uat` passes
  `--sha=$COMMIT_SHA`.

Set `UAT_OUTCOME="WARNING — no uat-* build found; see harness-bugs.md"`.

**2. Wait for terminal state:**
```bash
BUILD_STATUS=$(bash scripts/wait-for-build.sh "$UAT_BUILD_ID" 10)
# exit 0=SUCCESS, 1=failure, 2=timeout
```

**3a. If SUCCESS:**
```bash
UAT_URL=$(gcloud secrets versions access latest \
  --secret="${CLAUDE_UAT_SECRET:?set CLAUDE_UAT_SECRET}" --project="$CLAUDE_GCP_PROJECT")
curl -sf "$UAT_URL/health" && echo "UAT health OK"
```
Set `UAT_OUTCOME="SUCCESS — $UAT_URL"`.

**3b. If FAILURE or timeout:**
Fetch log URL:
```bash
gcloud builds describe "$UAT_BUILD_ID" --region="$CLAUDE_GCP_REGION" \
  --project="$CLAUDE_GCP_PROJECT" --format="value(logUrl)"
```
Append to `<phase-dir>/harness-bugs.md`:
```
## Bug — UAT build failed — Step 3c-uat
**Where:** Step 3c-uat — UAT deployment monitoring
**What happened:** UAT Cloud Build <UAT_BUILD_ID> reached state <BUILD_STATUS>
**Root cause:** UAT deployment pipeline failure — see log at <logUrl>
**Suggested fix:** Investigate Cloud Build log; re-push uat-* tag after fix
```
Set `UAT_OUTCOME="FAILED — see harness-bugs.md"`.

### 3d. Update GitHub issues

Re-read `<phase-dir>/00-pipeline.md` and extract the `issues:` field. If the field is absent (older phases without issue tracking), skip this step silently.

**For each issue number in `issues.resolved`:**
```bash
gh issue close <N> --comment "Closed by Phase <phase> — <pipeline description>.

Delivered in steps: <comma-separated step ids>
Phase completed: <today's date YYYY-MM-DD>"
```

**For each issue number in `issues.partial`:**
```bash
gh issue comment <N> --body "**Phase <phase> progress update** — <pipeline description>

This phase partially addressed this issue. Steps completed: <comma-separated step ids>.

Remaining work will be tracked in a future phase."
```

Report what was done:
```
GitHub issues updated:
  Closed: #<N>, #<N> (resolved)
  Commented: #<N> (partial progress)
```

### 3e. File harness bugs as GitHub issues (single pass)

This step runs after Step 3c (fix-ci) so that bugs logged by fix-ci's subagent are captured.

Check whether `<phase-dir>/harness-bugs.md` exists:

```bash
test -f <phase-dir>/harness-bugs.md && echo "EXISTS" || echo "ABSENT"
```

**If absent:** skip this step silently.

**If present:** for each `## Bug —` entry in the file, check whether an open issue with the
same title already exists (to avoid duplicates):

```bash
gh issue list --label harness --state open --json number,title --limit 50
```

For each entry with no matching open issue, file a new one:

```bash
gh issue create \
  --title "harness: <short title from bug entry>" \
  --label harness \
  --body "**Detected during:** Phase <phase> pipeline run

**Where:** <step where detected>

**What happened:**
<what happened text>

**Root cause:**
<root cause text>

**Suggested fix:**
<suggested fix text>

*Auto-filed by ralph-pipeline Step 3e from `<phase-dir>/harness-bugs.md`.*"
```

Report each issue filed:
```
Harness bugs filed:
  #<N> — <title>
```

If all entries already had matching open issues, report:
```
Harness bugs: all already tracked (no new issues filed)
```

### 3f. File concerns as GitHub issues

Check whether `<phase-dir>/concerns.md` exists:

```bash
test -f <phase-dir>/concerns.md && echo "EXISTS" || echo "ABSENT"
```

**If absent:** skip this step silently.

**If present:** parse the file for concern sections. Each section heading is `## <step-id>` followed by either "no concerns" or a structured concern block. Skip any section that contains "no concerns".

For each real concern section, extract:
- `**Category:**` value → map to a GitHub label:
  - `missing-info` → `prompt-quality`
  - `bug` → `bug`
  - `unexpected-behaviour` → `bug`
  - anything else → `enhancement`
- `**Prompt section:**` value → use in the issue title
- `**What I encountered:**` value → issue body detail
- `**What I did:**` value → issue body detail
- `**Suggested fix:**` value → issue body detail

Ensure the `prompt-quality` label exists before filing (create it if missing):

```bash
gh label create "prompt-quality" --color "#e4e669" --description "Prompt quality gap identified during a ralph-pipeline run" 2>/dev/null || true
```

For each concern with no matching open issue (deduplicate by title prefix `concern(<step-id>):`):

```bash
gh issue list --label <mapped-label> --state open --json number,title --limit 100
```

File each new concern as an issue:

```bash
gh issue create \
  --title "concern(<step-id>): <one-line summary from What I encountered>" \
  --label "<mapped-label>" \
  --body "**Phase:** <phase> — step \`<step-id>\`
**Category:** <category>
**Prompt section:** <prompt section>

**What I encountered:**
<what I encountered text>

**What I did:**
<what I did text>

**Suggested fix:**
<suggested fix text>

*Auto-filed by ralph-pipeline Step 3f from \`<phase-dir>/concerns.md\`.*"
```

Report each issue filed:
```
Concerns filed as issues:
  #<N> — <title>  [<label>]
```

If all real concerns already had matching open issues, report:
```
Concerns: all already tracked (no new issues filed)
```

If there were no real concerns (all sections said "no concerns"), report:
```
Concerns: none recorded this run
```

### 3g. Write run record

After issues are updated, update the run record in `prompts/phase-runs.yaml`.

**Tally concerns** from the phase directory:

```bash
CONCERNS_FILE="<phase-dir>/concerns.md"
if [ -f "$CONCERNS_FILE" ]; then
  # Initialise to 0 first — grep -c exits 1 (no matches) but still prints "0",
  # so the common "|| echo 0" pattern produces "0\n0" and breaks arithmetic.
  # Instead: initialise, then only assign if a match exists.
  C=0; M=0; A=0
  grep -q '\*\*Category:\*\* contradiction' "$CONCERNS_FILE" 2>/dev/null && \
    C=$(grep -c '\*\*Category:\*\* contradiction' "$CONCERNS_FILE")
  grep -q '\*\*Category:\*\* missing-info'  "$CONCERNS_FILE" 2>/dev/null && \
    M=$(grep -c '\*\*Category:\*\* missing-info'  "$CONCERNS_FILE")
  grep -q '\*\*Category:\*\* assumption'    "$CONCERNS_FILE" 2>/dev/null && \
    A=$(grep -c '\*\*Category:\*\* assumption'    "$CONCERNS_FILE")
  CONCERN_SCORE=$(( C * 3 + M * 2 + A * 1 ))
  CONCERNS_FILE_PATH="$CONCERNS_FILE"
else
  C=0; M=0; A=0
  CONCERN_SCORE=0
  CONCERNS_FILE_PATH="null"
fi
```

**Get total cost** from stop-hook telemetry if available (best-effort — use `null` if not):

```bash
# Stop-hook writes telemetry to .claude/ralph-loop/telemetry/ — sum cost_usd for this phase
```

**Upsert run record in `prompts/phase-runs.yaml`:**

1. Read `prompts/phase-runs.yaml`
2. Find the entry where `run_id = <RUN_ID>`
3. Update these fields in-place:
   ```yaml
   completed_at: "<now ISO-8601>"
   outcome: success
   concern_score: <CONCERN_SCORE>
   concerns_file: <CONCERNS_FILE_PATH or null>
   ```
4. Write the file back — do **not** append a new entry

**Note on outcome values:** valid outcomes are `in-progress`, `success`, `failed`, and `abandoned`.
A run is marked `outcome: abandoned` when a restart is chosen at Step -1b (see main skill),
or when a pre-existing in-progress record is superseded at Step 0b-ii.

**Fallback:** if no entry with the matching `run_id` is found (e.g. `phase-runs.yaml` was
manually edited or truncated), fall back to appending a new record with the full schema:

```yaml
  - phase_id: "<phase>"
    run_id: "<RUN_ID>"
    started_at: null
    completed_at: "<now ISO-8601>"
    outcome: success
    start_sha: null
    steps_total: []
    steps_completed: []
    concern_score: <CONCERN_SCORE>
    concerns_file: <CONCERNS_FILE_PATH>
    total_cost_usd: null
    notes: null
```

**Write execution fields to phases.yaml:**

Find the phases.yaml entry where `id = <PHASE_ID>` and add the following fields after `status: completed`:

```yaml
    concern_score: <CONCERN_SCORE>
    concerns_file: <CONCERNS_FILE_PATH or null>
    steps_total: <list of all step ids from 00-pipeline.md, or null>
    steps_completed: <list of completed step ids from run state, or null>
    started_at: <START_TIME from run record, or null>
    completed_at: "<now ISO-8601>"
```

**Remove the completed phase entry from phase-runs.yaml:**

Read `prompts/phase-runs.yaml`. Remove all entries where `phase_id = <PHASE_ID>`. Write the file back. A successfully completed phase leaves `runs: []` between phases.

Report the concern score alongside the run record path. Always show the full breakdown
so the reader can see whether the score came from the grep matching correctly:

```
Run record written: prompts/phase-runs.yaml (run <run-id>)

Concern score: <CONCERN_SCORE>
  Contradictions (×3):  <C>
  Missing-info  (×2):  <M>
  Assumptions   (×1):  <A>
  ─────────────────────────
  Total:               <CONCERN_SCORE>

Concerns file: <CONCERNS_FILE_PATH or "none">
```

If `concern_score > 0`, add on a new line:
```
→ Run `/ralph-prompt-review --post-run <phase-dir>` to review concerns and get corpus update recommendations.
```

If the concerns file exists but the score is 0, also note: "Score is 0 — verify grep patterns matched the file's **Category:** lines."

### 3h. Final commit and report

> **Only permitted `git add prompts/phase-runs.yaml` point:** This is the sole place in either skill file where `prompts/phase-runs.yaml` is committed. No step subagent and no earlier pipeline step may commit this file.

Commit the registry and run-record updates. Always use an absolute path to avoid CWD drift:

```bash
cd /workspaces/ralph-wiggum-experiment && git add prompts/phases.yaml prompts/phase-runs.yaml && git commit -m "chore(harness): mark phase-<phase> completed in registry, close #<issue>"
```

Then push:

```bash
cd /workspaces/ralph-wiggum-experiment && git push origin main
```

### 3i. Trailing state cleanup

Unconditionally remove any orphaned state file left by a subagent:

```bash
rm -f ~/.ralph/loop-state.md && echo "State file cleanup complete" || echo "No state file present"
```

This catches state files leaked by fix-ci's ralph-loop subagent that Step 3a could not
have seen (Step 3a ran before fix-ci was invoked).

### 3j. Report

```
Pipeline complete.
Steps executed: <list>
All tests: PASS

Concern score: <CONCERN_SCORE>  (<C> contradiction × 3, <M> missing-info × 2, <A> assumption × 1)
Harness bugs filed: <N> (omit line if 0)
CI triggered: <build-id> on branch <branch>  ← omit line if no app code changes
UAT deployment: ⚠️ <UAT_OUTCOME>  ← prefix ⚠️ when UAT_OUTCOME starts with WARNING or FAILED; omit line if Step 3c-uat was skipped
```
