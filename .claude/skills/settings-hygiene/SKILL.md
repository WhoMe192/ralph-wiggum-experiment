---
name: settings-hygiene
description: >
  Analyses .claude/settings.json for overly-specific permission entries. Proposes wildcard
  consolidations and one-off removal. Dry-run by default; --apply to write.
  Triggers: 'settings hygiene', 'consolidate permissions', '/settings-hygiene'.
argument-hint: "[--apply]"
disable-model-invocation: true
---

## Inputs

**Zero-input skill.** No user argument is required. Run as `/settings-hygiene` (dry-run) or `/settings-hygiene --apply` (write changes after confirmation).

**If `.claude/settings.json` does not exist:** stop and report: "`.claude/settings.json` not found. Nothing to analyse."

**If the file exists but is not valid JSON:** stop and report: "`.claude/settings.json` contains invalid JSON. Fix the syntax before running this skill. Use `node -e \"JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'))\"` to see the parse error."

**If `permissions.allow` is absent or is not an array:** stop and report: "No `permissions.allow` array found in `.claude/settings.json`. Nothing to analyse."

**Failure criteria:** This skill fails if any of the above guards trigger, or if `--apply` was confirmed but the write to `settings.json` exits non-zero.

## Introduction

Over time, `.claude/settings.json` accumulates permission entries as new tools and commands are approved. Some entries are overly specific — for example, three separate `Bash(gh issue list:*)`, `Bash(gh issue view:*)`, and `Bash(gh issue edit:*)` entries could safely be collapsed into a single `Bash(gh issue *:*)`. Others are one-off path-specific entries tied to a specific migration or bootstrap task that will never recur. As the list grows, it becomes difficult to audit and maintain. Invoke `/settings-hygiene` to get a structured report of consolidation candidates and stale one-offs for human review. Run `/settings-hygiene --apply` to write the proposed changes after confirmation.

## Step 1 — Read settings.json

Read the current permissions file:

```bash
cat .claude/settings.json
```

Parse the `permissions.allow` array. Each entry is a string such as `Bash(git *:*)`, `Edit(/.claude/skills/**)`, `Skill(ralph-*:*)`, or `WebFetch(domain:docs.anthropic.com)`. Extract the tool prefix (the part before the first `(`) and the argument (the content inside the outer parentheses).

## Step 2 — Classify entries by type

Group entries by their tool prefix. Common prefixes include:

- `Bash` — shell commands; argument is the command pattern
- `Edit` — file editing; argument is a path glob
- `Write` — file writing; argument is a path glob
- `Read` — file reading; argument is a path glob
- `Skill` — skill invocations; argument is the skill name pattern
- `WebFetch` — web requests; argument is a domain or URL pattern
- `Agent` — sub-agent invocations
- `mcp__*` — MCP tool permissions

Within the `Bash` group, further sub-group by the leading command word (e.g. `git`, `gh`, `npm`, `node`, `curl`, `chmod`, `bash`, `find`, `rm`, etc.).

## Step 3 — Identify collapse candidates

For each sub-group within `Bash`:

1. List all unique command sub-prefixes within the sub-group (e.g. `gh issue list`, `gh issue view`, `gh issue edit`).
2. Determine the common prefix (e.g. `gh issue`).
3. If **all** entries in the sub-group are read-type operations, the sub-group is a collapse candidate; propose `Bash(<common-prefix> *:*)`.
4. **Safety rule:** if **any** entry in the sub-group is write-type (creates files, modifies state, sends data), the **entire sub-group is NOT collapsible** — leave it as-is.

**Read-type heuristics** (commands that only observe, never mutate):
`list`, `view`, `show`, `get`, `read`, `cat`, `ls`, `grep`, `which`, `curl` (only when no `-X POST`, `-X PUT`, `-X PATCH`, `-X DELETE`, `--data`, `-d`, or `--request` flag is present), `node --check`, `wc`, `head`, `tail`, `diff`, `log`, `status`, `version`, `--version`, `-v`

**Write-type heuristics** (commands that create, modify, or delete):
`create`, `edit`, `delete`, `push`, `commit`, `add`, `rm`, `mv`, `write`, `POST`, `PUT`, `PATCH`, `chmod`, `mkdir`, `rmdir`, `kill`, `export`

**When uncertain:** classify as write-type. Err on the side of caution.

For non-`Bash` groups (e.g. `Edit`, `Write`, `Skill`, `WebFetch`): collapse is possible only when multiple entries share a common path prefix or domain that can be expressed with a single wildcard without broadening write access inappropriately.

## Step 4 — Identify one-off removal candidates

Flag entries matching **any** of these patterns:

- Contains a fully-qualified absolute path that is project-specific and looks like a migration or bootstrap artifact (e.g. `Bash(mkdir -p /workspaces/ralph-wiggum-experiment/infra:*)`)
- Looks like a one-time setup or rename command unlikely to recur
- Exact-command entries (no wildcards) that reference specific file paths that no longer exist in the repo

**Never flag:**
- Entries that use wildcards (`*`, `**`)
- Entries with generic commands that could plausibly recur
- Any entry where removal would reduce needed ongoing access

## Step 5 — Identify sensitive entries (never collapsed)

Flag entries whose argument string contains any of the following keywords (case-insensitive):
`token`, `password`, `secret`, `key`, `credential`, `oauth`, `auth`

These entries are listed in their own section of the report and are **never** proposed for consolidation or removal.

## Step 6 — Print report

Print a structured report in the following format:

```
settings.json hygiene report
════════════════════════════

Collapse candidates:
  [Bash — gh issue] 3 entries → Bash(gh issue *:*)  ✅ safe (all read-type)
  ...

One-off removal candidates:
  Bash(mkdir -p /workspaces/ralph-wiggum-experiment/infra:*)  [path-specific]
  ...

Sensitive entries (not collapsed):
  ...  (or "None" if no sensitive entries found)

Entries with no suggested changes: <N>

Run /settings-hygiene --apply to write these changes.
```

If no candidates are found in any category, print:

```
No consolidation candidates found. settings.json looks clean.
```

## Step 7 — Apply (only if --apply flag provided)

If the `--apply` flag was **not** provided, stop after the report. Do not modify `settings.json`.

If `--apply` **was** provided:

1. Use `AskUserQuestion` to show the exact proposed diff and ask: *"Apply these changes to .claude/settings.json? (yes/no)"*
2. If the user answers **yes**: rewrite the `permissions.allow` array — replace each collapse-candidate group with its single wildcard entry, remove all one-off entries, and preserve every other entry and the overall JSON structure (including `additionalDirectories`, `model`, `hooks`, and `enabledPlugins`).
3. Print confirmation: `settings.json updated. <N> entries consolidated, <M> one-offs removed.`
4. If the user answers **no**: print `Aborted. No changes made.` and exit without modifying the file.

## Idempotency

Running `/settings-hygiene` on an already-clean `settings.json` produces "No consolidation candidates found." Running `--apply` on a file with no candidates produces the same message and writes nothing.

## Standards and co-update partners

Heuristics are based on Claude Code's permission model. If the Claude Code permission system adds new tool types, update Step 2's prefix list and Step 3's heuristics table accordingly.
