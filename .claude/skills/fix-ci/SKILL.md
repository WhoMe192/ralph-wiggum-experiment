---
name: fix-ci
description: >
  Check Cloud Build gate and auto-fix failures. Tracks in GitHub issues, runs up to 5
  fix iterations, closes or marks stuck. Triggers: 'fix ci', 'ci failed', 'ci is red',
  'build is broken', '/fix-ci'. Do not use for known flaky tests.
allowed-tools: Bash, Read, Write, Glob, Grep, Skill, AskUserQuestion
---

> **⚠️ GCP-ONLY:** This skill targets GCP Cloud Build. Non-GCP projects should not invoke it; a GitHub Actions variant is tracked as future work. Requires env vars `CLAUDE_GCP_PROJECT` and `CLAUDE_GCP_REGION`; helper scripts exit with an error if they are unset.

## Inputs

| Input | Source | Values | Required |
|-------|--------|--------|----------|
| `--env` | Invocation args | `dev` (default), `uat`, `prod` | No — defaults to `dev` |
| Current branch | `git rev-parse --abbrev-ref HEAD` | Any branch name | Auto-detected (Dev only) |
| Cloud Build ID | Detected from `gcloud builds list` | UUID format | Auto-detected |

**Iteration limit:** Maximum automated fix attempts = **5** (passed as `--max-iterations 5` to the ralph-loop subagent in Step 9). See the Standards section for rationale.

**Do not use when:**
- CI failure is a known flaky test — check the issue tracker first.
- The build failure is in UAT or Prod and no human approval is available.

**Edge cases:**
- Unknown `--env` value: stop — "Unknown --env value. Use dev, uat, or prod."
- No builds found for branch: stop — "No Cloud Build results found for branch `$BRANCH`..."
- `extract-failure.py` exits non-zero or invalid JSON: stop — "Failed to extract failure details from build `$BUILD_ID`. Run `gcloud builds log $BUILD_ID --region="$CLAUDE_GCP_REGION"` to inspect manually."
- `prompts/ci-fixes/TEMPLATE.md` missing: stop — "`prompts/ci-fixes/TEMPLATE.md` not found — check fix-ci skill installation."

# Fix CI

Check the Cloud Build PR gate result for the current branch and auto-fix failures using ralph-loop.
Failures are tracked in GitHub Issues. Fix prompts are generated from a standard template for consistent context.

## Scripts bundled with this skill

| Script | Purpose |
|---|---|
| `scripts/wait-for-build.sh <build-id> [max-minutes]` | Poll until build reaches terminal state; exits 0=SUCCESS / 1=failure / 2=polling-timeout |
| `scripts/extract-failure.py <build-id>` | Scrape log, write `/tmp/ci-failure-<id>.json`, print path |
| `scripts/generate-prompt.py --failure-json <path> --branch <b> --build-id <id> --template <t> --output-dir <d>` | Fill template, write timestamped prompt, print path |

## Project CI config

```
SKILL_DIR=.claude/skills/fix-ci
REGION="${CLAUDE_GCP_REGION:?set CLAUDE_GCP_REGION}"
PROJECT="${CLAUDE_GCP_PROJECT:?set CLAUDE_GCP_PROJECT}"
```

## Argument parsing

- `--env=dev` or omitted → `ENV=dev`; `--env=uat` → `ENV=uat`; `--env=prod` → `ENV=prod`
- Unknown value: stop with error.

## Step 1 — Detect branch (dev only)

**If `ENV != dev`:** skip. **If `ENV = dev`:** `BRANCH=$(git rev-parse --abbrev-ref HEAD)`

## Step 2 — Find the most recent build

**Dev:** `gcloud builds list --region="$CLAUDE_GCP_REGION" --project="$CLAUDE_GCP_PROJECT" --filter="substitutions.BRANCH_NAME=$BRANCH" --limit=3 --format="table(id,status,createTime)"`

If no builds match, fall back to 3 most recent overall and ask user which build ID to use.

**UAT:** same command with `--filter="tags:uat-*" --sort-by="~createTime"` and `tags` column.

**Prod:** same as UAT with `--filter="tags:prod-*"`. Warn: re-triggering pushes a new `prod-*` tag and deploys to production. Confirm before proceeding.

Capture the most recent `BUILD_ID`.

## Step 3 — Wait for the build to reach a terminal state

```bash
BUILD_STATUS=$(bash $SKILL_DIR/scripts/wait-for-build.sh $BUILD_ID)
```

Exit code 2 = 15-minute polling timeout — ask user whether to keep waiting.

## Step 4 — Handle result

- **SUCCESS:** Report "CI PASSED — build `$BUILD_ID`." Close any open `ci-failure` issue for the branch. Stop.
- **FAILURE / TIMEOUT / CANCELLED:** Proceed to Step 5.
- **No build found:** Report no results; instruct user to push branch and re-run. Stop.

## Step 5 — Extract failure details

```bash
FAILURE_JSON=$(uv run python $SKILL_DIR/scripts/extract-failure.py $BUILD_ID)
FAILING_STEP=$(python3 -c "import json; d=json.load(open('$FAILURE_JSON')); print(d['failing_step'])")
PASSING_INLINE=$(python3 -c "import json; d=json.load(open('$FAILURE_JSON')); print(d['passing_steps_inline'])")
```

## Step 5.5 — Classify error type

```bash
ERROR_TYPE=$(python3 -c "import json; d=json.load(open('$FAILURE_JSON')); print(d.get('error_type', 'unknown'))")
```

**If `ERROR_TYPE = permission`:** This failure cannot be fixed by code changes. Skip Steps 6–9.

1. Ensure labels exist (`ci-failure`, `needs-human`) via `gh label create ... 2>/dev/null || true`.
2. Check for existing open issue (same logic as Step 7a); create or update with both labels.
3. Post remediation comment with deduplication marker:
   ```bash
   gh issue comment $ISSUE_NUM --body "<!-- fix-ci-$BUILD_ID -->
   **Permission error — automated fix not possible.**
   **Suggested remediation:**
   - IAM role missing: \`cd infra && tofu apply -auto-approve\`
   - Secret Manager access: grant \`roles/secretmanager.secretAccessor\` to the Cloud Build SA
   - Quota exceeded: request increase via GCP Console
   Manual intervention required — labelled \`needs-human\`."
   ```
4. Report (Blocked template — see Output template section). Stop.

**If `ERROR_TYPE` is `code`, `build`, or `unknown`:** proceed to Step 6.

## Step 6 — Ensure the GitHub labels exist

```bash
gh label create ci-failure  --color E11D48 --description "Automated CI gate failure" 2>/dev/null || true
gh label create stuck       --color F97316 --description "Blocked, needs manual attention" 2>/dev/null || true
gh label create needs-human --color 0075CA --description "Requires manual intervention" 2>/dev/null || true
```

## Step 7 — Check for or create a GitHub issue

### 7a. Check for an existing open issue

```bash
gh issue list --label ci-failure --state open --search "PR gate failure on $BRANCH" --json number,title --limit 1
```

### 7b. Create an issue if none exists

Issue title: `ci: PR gate failure on $BRANCH — $FAILING_STEP` (dev) / `ci(uat): ...` (uat) / `ci(prod): ...` (prod).

```bash
ISSUE_NUM=$(gh issue create --title "$TITLE" --label ci-failure \
  --body "<!-- fix-ci-$BUILD_ID -->
## CI Failure
**Branch:** $BRANCH  **Build ID:** $BUILD_ID  **Failing step:** \`$FAILING_STEP\`
**Steps passing:** $PASSING_INLINE
## Error excerpt
\`\`\`
$(python3 -c "import json; print(json.load(open('$FAILURE_JSON'))['error_excerpt'])")
\`\`\`
Being investigated by an automated ralph-loop. Closed when green, or marked stuck after 5 attempts." \
  | grep -oE '[0-9]+$')
```

### 7c. Comment on existing issue (if found in 7a)

```bash
gh issue comment $ISSUE_NUM --body "<!-- fix-ci-$BUILD_ID -->
New failure: build \`$BUILD_ID\` — \`$FAILING_STEP\` failed again. Starting ralph-loop fix attempt."
```

**Idempotency:** all GitHub comments and issue bodies include a `<!-- fix-ci-<run-id> -->` HTML comment marker. Before posting, check whether a comment with `<!-- fix-ci-$BUILD_ID -->` already exists on the issue; if it does, skip the post.

## Step 8 — Generate the fix prompt

```bash
PROMPT_FILE=$(uv run python $SKILL_DIR/scripts/generate-prompt.py \
  --failure-json "$FAILURE_JSON" --branch "$BRANCH" --build-id "$BUILD_ID" \
  --template prompts/ci-fixes/TEMPLATE.md --output-dir prompts/ci-fixes)
```

## Step 9 — Run ralph-loop to fix

Capture SHA, then spawn subagent via `Agent` tool (not `Skill`) — subagent type `general-purpose`:

```
You are running a ralph-loop to fix a Cloud Build CI failure.
  skill: ralph-loop
  args: "Read @<PROMPT_FILE> for the requirements --max-iterations 5 --completion-promise DONE"
Working directory: /workspaces/ralph-wiggum-experiment
```

After subagent returns: `rm -f ~/.ralph/loop-state.md`

**UAT only:** check `git diff --name-only $ORIGINAL_SHA HEAD`:
- `orchestrator/` changed → push `uat-$(git rev-parse --short HEAD)-fix`
- `infra/` only → `cd infra && tofu apply -auto-approve`
- Neither → label `stuck`, comment with deduplication marker, report Needs escalation. Stop.

## Step 10 — Post-loop verification

```bash
BUILD_INFO=$(gcloud builds list --region="$CLAUDE_GCP_REGION" --project="$CLAUDE_GCP_PROJECT" \
  --filter="substitutions.BRANCH_NAME=$BRANCH" --limit=1 --format="value(id,status)")
LATEST_BUILD_ID=$(echo "$BUILD_INFO" | awk '{print $1}')
LATEST_STATUS=$(echo "$BUILD_INFO" | awk '{print $2}')
```

- **SUCCESS:** close issue with `<!-- fix-ci-$LATEST_BUILD_ID -->` comment. Report Fixed template.
- **FAILURE:** comment on issue with deduplication marker and next-step guidance; add `stuck` label. Report Needs escalation template.

## Output template

| Verdict | Trigger condition |
|---------|------------------|
| `Fixed` | `LATEST_STATUS = SUCCESS` after ralph-loop |
| `Already done` | `BUILD_STATUS = SUCCESS` on entry (Step 4) |
| `Blocked` | `ERROR_TYPE = permission`, or no build found for branch |
| `Needs escalation` | ralph-loop exhausted all 5 iterations; CI still failing |

**Fixed:**
```
### Run complete
**Status:** Fixed
**Actions taken:**
- Detected failure: `npm test` step in build `abc-1234`
- Opened GitHub issue #42: "ci: PR gate failure on feat/my-branch — npm test"
- Ran ralph-loop (2 iterations); CI build `abc-5678` reached SUCCESS
**Output:** Issue #42 closed with passing build reference.
```

**Needs escalation:**
```
### Run blocked
**Status:** Needs escalation
**Reason:** CI still failing on `npm test` after 5 ralph-loop iterations (build `abc-9999`).
**Next step:** Review build log: `gcloud builds log abc-9999 --region="$CLAUDE_GCP_REGION"`
Issue #42 labelled `stuck`.
```

**Blocked:**
```
### Run blocked
**Status:** Blocked
**Reason:** Permission error — `error_type: permission` in build `abc-1234`.
**Next step:** Grant required IAM role or Secret Manager access (see issue #43), then re-run `/fix-ci`.
```

**Already done:**
```
### Run complete
**Status:** Already done
**No changes made.** CI build `abc-1234` is already SUCCESS on `feat/my-branch`. Re-run is safe.
```

## Success criteria

Succeeds when: CI build is SUCCESS and tracking issue is closed with a passing build reference.
Fails if: no build found (stop), permission error (label `needs-human`, stop), or 5 iterations exhausted (label `stuck`).

## Standards

Commit messages follow Conventional Commits (https://www.conventionalcommits.org). Co-update partner: smart-commit.

<!-- TODO: add fix-ci to the relationship map in docs/skill-design-standards.md under
     "Conventional Commits standard" alongside smart-commit. Do NOT edit that file here. -->

- Environment config (`REGION`, `PROJECT`) also in `.claude/skills/gcp/SKILL.md` — keep in sync
- Use `uv run python` for Python scripts, `tofu` for infra — never bare `python3` or `terraform`
- **5-iteration limit:** Each iteration = one fix + one Cloud Build run (~3–5 min). 5 = up to 25 min automated recovery. Beyond that, human review adds more value. If raising, update Inputs section, `--max-iterations` arg, issue body, and stuck message.
- **15-min polling timeout:** Cloud Build typically finishes in 3–8 min. Exit code 2 triggers user prompt rather than hanging.

## Calibration

- **Strong:** `cloudbuild-deploy.yaml` — reference CI config; a successful fix loop runs detect → extract → generate prompt → fix → verify → close issue against this file.
- **Weak:** `cloudbuild-uat.yaml` — had known substitution issues (commit cc08551); `ERROR_TYPE` classification was skipped and permission failures were incorrectly routed to ralph-loop.

See `docs/skill-calibration-manifest.md` §Infrastructure and CI skills.
