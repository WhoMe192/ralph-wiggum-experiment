# Ralph Prompt Create — PROMPT File Structure

Read this file when ready to write the phase prompt. Write sections in the exact order shown below. Every section is required.

Write the file using this exact section order. Every section is required.

---

### Section 1 — Title and Context

```markdown
# <Project Name>: Phase N — <Short Phase Title>

## Context

<2–4 sentences: what exists today, what this phase changes, and why.>

- Prior phases and their status (deployed / code-complete / superseded)
- What must NOT be touched (file paths, services, infra)
- Tooling already locked in (e.g. "OpenTofu only — never terraform")
- Files the agent must read before starting (e.g. "Read infra/main.tf before writing orchestrator.tf")
```

---

### Section 2 — What to Build

```markdown
## What to build

| File | Action |
|------|--------|
| path/to/file.js | Create — <one-line description> |
| path/to/config.tf | Update — <one-line description> |
| docs/deployment.md | Update — add Phase N runbook |
```

Every output file must appear here — nothing implied in prose only. One row per file.

---

### Section 3 — Deliverable specifications

One subsection per major deliverable:

**Service/API deliverable:**
```markdown
## Deliverable N: <Name>

### `POST /endpoint` — request
<JSON example>

### `POST /endpoint` — response
<JSON example with all fields; include error shape>

### Processing steps (implement in this order)
**Step 1 — <name>:** <concrete action>
**Step 2 — <name>:** <concrete action>

### Environment variables
| Variable | Source |
|----------|--------|
| VAR_NAME | GCP Secret Manager |

### Dependencies
<explicit list: package names, no implicit choices>
```

**Infrastructure deliverable:**
```markdown
## Deliverable N: `infra/file.tf`

Before writing, read `infra/main.tf` to understand:
- Provider / variable blocks already declared (do not re-declare)
- Existing resource names to reference

The new file must:
- <specific resource to create>
- <specific output to add>
- <specific constraint, e.g. min_instance_count = 0>
```

**Documentation deliverable:**
```markdown
## Deliverable N: `docs/deployment.md` / `docs/`

<List exactly what sections to add, update, or deprecate.>
<For runbooks: include the bash commands with placeholder variable names explained. Add as a new ## Phase N section in docs/deployment.md.>
<For superseded sections: show the exact banner text to prepend.>
<Do NOT add runbooks or deployment steps to CLAUDE.md — that file is for repo-working conventions only.>
```

---

### Section 4 — Constraints

```markdown
## Constraints

- **Security**: <auth check order, what must never be logged, how secrets are passed>
- **<Tool name>**: <what to use / what never to use — be explicit>
- **No changes to**: <file paths from prior phases>
- **Model choices**: <which model for which task, and why>
- **Out of scope**: <explicit list of things this phase does NOT include>
- **Test reference**: `<path/to/test-file>` is the reference input. Expected output: <brief description>.
```

---

### Section 5 — Self-verification

```markdown
## Self-verification (run after each file is written)

```bash
# <Deliverable type — e.g. Node.js source>
node --check <source-dir>/index.js

# <Deliverable type — e.g. OpenTofu>
cd infra && tofu validate

# <Deliverable type — e.g. health endpoint>
curl -s "$ORCHESTRATOR_URL/health"
# Expected: {"ok":true}
```

Fix any errors before moving to the next deliverable.
```

Mandatory checks by file type:
| Type | Command |
|------|---------|
| Node.js | `node --check <file>` |
| Python | `uv run python -m py_compile <file>` |
| Shell | `bash -n <script>` |
| JSON | `python3 -m json.tool <file> > /dev/null && echo OK` |
| OpenTofu | `cd infra && tofu validate` |
| Markdown | `test -s <file> && echo OK` |
| Skill file invoking corpus-query | `grep -C5 "corpus-query" <file> \| grep -q "Agent tool" && echo OK` |
| Live service | `curl -s <health-url>` with expected response shown |

---

### Section 6 — Loop execution strategy

```markdown
## Loop execution strategy

### One deliverable per iteration

Do **at most one** of the following per iteration:

1. <Group 1>
2. <Group 2>
3. <Group 3 — small related files can be grouped: "CLAUDE.md + README — do both in one iteration">

Use `TodoWrite` at the start of every iteration to record progress. Check `git status` before deciding what to do next.

### Use a subagent for every file write

Use the `Agent` tool (subagent_type `general-purpose`) for all file writes. Pass the relevant prompt section plus any existing file content needed. Do **not** write file contents inline in your own response.

### Do not echo large file contents

Describe what was changed — do not reproduce full file contents in your response.

### Progress updates

End every iteration with:

```
[Iteration N] STATUS: <one sentence summary>
Remaining: <comma-separated outstanding deliverables>
```

### Escape hatch

If after 10 iterations a deliverable is still not complete, document the blocker in `docs/phase<N>-blockers.md` and continue. Do not loop forever on a single file.

### Concerns log

If at any point during execution you encounter any of the following, append an entry to
`prompts/phase-<N>/concerns.md` **before proceeding**:

- **Contradiction:** the prompt contains two instructions that cannot both be satisfied
- **Missing information:** a deliverable requires a detail (API field, file path, config value,
  constraint) that the prompt does not provide and you cannot derive from the codebase
- **Assumption:** you made a choice the prompt did not specify, and a different choice would
  have produced a different output

Do not stop execution to ask — log the concern and proceed with your best judgement.
The file is reviewed by the human after the run; it is not a blocking mechanism.

Entry format:

```
## Concern — <category> — <step-id> — <timestamp>

**Category:** contradiction | missing-info | assumption

**Prompt section:** <e.g. Q5 — API shapes / Deliverable 2 / Constraints>

**What I encountered:**
<one or two sentences describing the gap>

**What I did:**
<the choice made to proceed>

**Suggested fix:**
<the specific text that, if added to the prompt, would have prevented this concern>
```
```

---

### Section 7 — Signal completion

```markdown
## Signal completion

Before outputting the completion signal, confirm ALL of the following:

1. All files in the deliverables table exist and are non-empty
2. `tofu validate` passes if any `.tf` files were created or modified
3. No placeholder values remain (`grep -r "REPLACE_ME\|YOUR_\|PROJECT_ID" --include="*.tf" --include="*.sh" --include="*.md"`)
4. `docs/deployment.md` contains a runbook for the new phase (not CLAUDE.md — that file is for repo-working conventions only)

Then output exactly: `DONE`
```