## Step 2 — Full suite test rules

Before running: check that `full_suite` includes both `npm test` and `npm run test:e2e`. If only `npm test`, warn:
> **Warning:** `full_suite` only runs <test-runner> — <e2e-runner> E2E excluded. Consider: `<project-defined full-suite command>`

Run (always prefix with the CWD guard to prevent subagent CWD drift):
```bash
cd /workspaces/ralph-wiggum-experiment && <full_suite_command>
```

> **Note on E2E failures in `full_suite`:** <e2e-runner> E2E tests require a deployed Cloud Run service. If `full_suite` fails due to E2E timeouts or connection errors (not <test-runner> failures), use **Option D — Deploy then retest** rather than treating the failure as a hard blocker. E2E failures in a local context are expected for backend/harness phases.

If `full_suite` fails, check for deployment signal patterns:
- HTTP responses with `Content-Type: text/html` where `application/json` was expected
- Status codes 404 on routes added in this pipeline
- `Unexpected token '<'`, `<!DOCTYPE`, `net::ERR_CONNECTION_REFUSED`

**If a deployment signal is detected:**
- **D. Deploy then retest** (recommended) — run `./scripts/deploy.sh`, then re-run `full_suite`.
- **A. Rewrite a step prompt** — fix incorrect output.
- **B. Skip full suite** — mark complete without E2E.
- **C. Abort** — stop and review manually.

If D is chosen and deploy succeeds, re-run full suite. If it fails again, present only A/B/C.

**If no deployment signal:** present A/B/C options only.