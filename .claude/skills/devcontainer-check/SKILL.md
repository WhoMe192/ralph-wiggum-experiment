---
name: devcontainer-check
description: This skill should be used when the user asks to "check the devcontainer", "verify tools are installed", "health check the environment", "check auth status", "is gcloud installed", "is gh authenticated", or wants to confirm the devcontainer is correctly set up after a rebuild.
allowed-tools:
  - Bash(which:*)
  - Bash(gcloud:*)
  - Bash(gh --version)
  - Bash(gh auth status)
  - Bash(tofu --version)
  - Bash(claude --version)
---

# Devcontainer Health Check

**Inputs:** This skill takes no arguments. It runs automatically against the current devcontainer environment using the tools available in the shell.

Run the following checks in order and report the status of each. Skip any tool not declared in `CLAUDE.md` `## Tech Stack` (mark **SKIP** with reason "not declared in project tech stack").

## Checks to perform

1. **gh** — run `which gh && gh --version` to confirm installation, then `gh auth status` to check authentication status. (Required.)
2. **claude** — run `which claude && claude --version` to confirm installation. (Required.)
3. **gcloud** — only if declared in CLAUDE.md tech stack. Run `which gcloud && gcloud --version`, then `gcloud auth list`.
4. **tofu** — only if declared in CLAUDE.md tech stack. Run `which tofu && tofu --version`.

## Error handling

Handle these failure modes for every check:

| Failure | Detection | Remediation to show user |
|---------|-----------|--------------------------|
| Command timeout (>30s) | Command does not return | "Command `[cmd]` timed out. Try running it manually in a new terminal." |
| Tool not found | `which` exits non-zero | "Not installed. Install via: `sudo apt-get install -y [package]`" |
| Tool installed but wrong version | `--version` output does not match expected constraint | Emit **WARN** (not FAIL) — note the version mismatch and recommended upgrade command |
| gcloud auth failure | `gcloud auth list` shows no active accounts | "Run: `gcloud auth login && gcloud auth application-default login`" |
| gcloud partial failure | Some gcloud subcommands fail after install passes | "Run `gcloud components update` and retry." |
| gh auth failure | `gh auth status` exits non-zero | "Run: `gh auth login`" |

**Partial success rule:** If a check partially succeeds (e.g. tool is installed but wrong version, or one auth scope passes but another fails), emit **WARN** not FAIL. Document both what passed and what needs attention in the Notes column.

Never stop early — always run all four checks and collect all errors before reporting.

## Reporting

For any tool that is missing, report it as NOT FOUND and recommend installing via apt (not curl scripts or devcontainer features — those have historically failed in this environment).

For any tool that is present but not authenticated, report what action is needed to authenticate.

Summarise all results as a table with columns: Tool | Installed | Authenticated | Notes.

For each failing row, append the exact remediation command in the Notes column.

### Verdict enum

Each cell in the Installed and Authenticated columns must use exactly one of these verdicts:

| Verdict | Meaning |
|---------|---------|
| `PASS` | Check succeeded with no issues |
| `WARN` | Partial success — tool present but wrong version, or auth partially configured |
| `FAIL` | Check failed — tool missing or auth completely absent |
| `SKIP` | Check not applicable (e.g. tofu and claude have no auth check) |

**Note on verdict convention:** PASS/WARN/FAIL/SKIP are the domain-specific labels for devcontainer check output cells — they describe tool/auth states, not skill-level quality scores. The project's dimension scoring convention (✅ Strong / ⚠️ Partial / ❌ Missing from `docs/skill-design-standards.md §Scoring conventions`) applies to skill review rubrics, not to the health-check output table produced by this skill. These two conventions are non-overlapping.

### Output template

Show results in this format:

```
## Devcontainer Health Check

| Tool    | Installed | Authenticated | Notes |
|---------|-----------|---------------|-------|
| gcloud  | PASS      | WARN          | Installed (v473.0.0). Auth: active account found but application-default credentials missing. Run: `gcloud auth application-default login` |
| gh      | PASS      | PASS          | Installed (v2.49.0). Authenticated as user@example.com |
| tofu    | PASS      | SKIP          | Installed (v1.7.1). No auth check required |
| claude  | PASS      | SKIP          | Installed (v1.2.3). No auth check required |

### Status: Partial

**Actions required:**
- gcloud: application-default credentials missing
  - Evidence: `gcloud auth list` showed active account but `gcloud auth application-default login` not run
  - Fix: `gcloud auth application-default login`
```

For a fully passing check, the Status line reads **Status: All clear** and the Actions required section is omitted.

For a blocked check (tool not installed), show:

```
### Status: Blocked

**Actions required:**
- gcloud: not installed
  - Evidence: `which gcloud` exited non-zero — command not found
  - Fix: `sudo apt-get install -y google-cloud-cli`
```

## Success criteria

This skill succeeds when: all four tools (gcloud, gh, tofu, claude) are installed and gcloud and gh are authenticated.

This skill reports a partial failure if any tool is missing or not authenticated, and specifies the remediation command. It never stops early — it always runs all four checks and reports the full table.

## Idempotency

On re-run: if the environment is unchanged, re-run all checks (no caching). This skill is safe to invoke repeatedly — it performs read-only shell commands and produces no side effects. Running it twice in a row will produce the same output.

## Do not use when

- Diagnosing application errors unrelated to environment setup (e.g. failing <test-runner> tests, broken API routes, <external-card> creation failures) — investigate the application logs directly instead.

## Standards

- Recommend `apt`-based installation for missing tools — do NOT suggest `ghcr.io/devcontainers/features/google-cloud-cli` or curl-based devcontainer features; these have historically failed in this environment (see memory: `feedback_devcontainer_gcloud.md`)
- Tool list reflects `docs/tech-stack.md` — add a new row if tech-stack.md adds a required CLI tool
- Configuration source: `.devcontainer/devcontainer.json` defines what should be present; use it as the reference when deciding whether a missing tool is expected or an oversight

### Why each tool is required

| Tool | Rationale | Source |
|------|-----------|--------|
| gcloud | Required by deployment scripts (`scripts/deploy.sh`) for Cloud Run deploys, image builds, and Secret Manager access | `docs/tech-stack.md` §gcloud; `scripts/deploy.sh` |
| gh | Required for git credential management and PR/tag automation; devcontainer installs it via `ghcr.io/devcontainers/features/github-cli:1` | `docs/tech-stack.md` §gh; `.devcontainer/devcontainer.json` |
| tofu | Required for infrastructure-as-code operations (`infra/`); always invoked via `scripts/deploy.sh`, never bare `tofu apply` | `docs/tech-stack.md` §OpenTofu |
| claude | Required to run the ralph-loop harness and all `/skills` commands that drive phase execution | `docs/tech-stack.md` §Claude Code CLI |

### Co-update partners

If a new required CLI tool is added to this project, update all of the following:
- `.devcontainer/devcontainer.json` — add installation step
- This skill — add a new check row under "Checks to perform" and a new error handling row
- `ralph-preflight` — if the tool is also required before phase execution
- `infra-preflight` — if the tool is required for infra operations

### Relationship map

| Related skill / file | Relationship |
|----------------------|--------------|
| `ralph-preflight` | Also checks CLI readiness before phase runs; devcontainer-check is broader (covers auth too) |
| `infra-preflight` | Validates IAM and YAML; assumes devcontainer tools are already present |
| `.devcontainer/devcontainer.json` | Canonical source for which tools should be installed in this environment |
| `docs/tech-stack.md` | Canonical source for required CLI tools; co-update when a new tool is added |

## Calibration

- **Strong:** `.devcontainer/devcontainer.json` — the target artefact this skill validates against; a clean post-rebuild run where all four tools match entries in devcontainer.json and gcloud + gh report authenticated is the passing reference.
- **Weak:** no committed failing-run log yet — update this entry when a devcontainer rebuild failure is documented in the project.

See `docs/skill-calibration-manifest.md` §Infrastructure and CI skills for the per-skill manifest entry.
