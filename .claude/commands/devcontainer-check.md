# Devcontainer Health Check

Verify all expected tools are available and authenticated after a rebuild.

## Steps

1. Check each tool is installed (`which <tool>` then `<tool> --version`):
   - `gcloud`
   - `gh`
   - `claude`
   - `tofu`

2. Check auth status for installed tools:
   - `gh auth status`
   - `gcloud auth list` (only if gcloud is installed)

3. Check git identity is configured:
   - `git config user.name`
   - `git config user.email`

4. Report a clear pass/fail summary for each item.

## Rules

- For any missing tool, provide the `apt install` command — do NOT suggest curl scripts or devcontainer features.
- Do not attempt to install or configure anything automatically; only report status and provide instructions.
