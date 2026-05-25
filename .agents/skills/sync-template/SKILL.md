---
name: sync-template
description: >
  Surfaces drift between a managed repo's agent-setup files (CLAUDE.md, AGENTS.md, .claude/settings.json) and the current version of the template it was
  created from. Shows a diff and optionally applies updates.
---

# Sync Template

## Steps

1. Accept a repo name or path as argument. If not provided:
   - Read `OCTO_WORKSPACE` from `.octo/config`
   - Scan `$OCTO_WORKSPACE/*/` for git repos
   - Also read `.octo/graph.yaml` for metadata
   - List discovered repos and ask the user to choose one

2. Resolve the repo path: if a name is given, look it up as `$OCTO_WORKSPACE/<name>`.
   Read `.octo/graph.yaml` to find the `template` and `template_version` for this repo.
   If the repo has no entry in graph.yaml, ask the user which template it was created from.

3. Find the template directory: `templates/<template>/`. Read `template.json` to get the
   current `version`.

4. Compare versions:
   - If `template_version` in graph.yaml matches the current template `version`:
     report "Repo is on template version <v> — up to date." and stop.
   - If `template_version` is empty or missing in graph.yaml:
     note that version tracking is unavailable and continue.
   - Otherwise: note the drift — "Repo was scaffolded from template v<old>, current is v<new>."

5. The sync scope is **agent-setup only** (`CLAUDE.md` and `.claude/settings.json`).
   Product code in `files/` is intentionally diverged and is never synced.
   Show this scope clearly to the user.

6. Compare the template's `agent-setup/` files against the repo's current files:
   ```bash
   diff templates/<template>/agent-setup/AGENTS.md <repo-path>/AGENTS.md
   diff templates/<template>/agent-setup/CLAUDE.md <repo-path>/CLAUDE.md
   diff templates/<template>/agent-setup/.claude/settings.json <repo-path>/.claude/settings.json
   ```
   Display each diff. If both files are identical, report "Agent setup is in sync — no changes needed."

7. If there are differences, ask the user for each changed file:
   - **Keep repo version** (do nothing)
   - **Apply template version** (overwrite with template file)
   - **Merge manually** (show both and let user decide in-conversation)

8. For any "Apply template version" choices, copy the template file to the repo:
   ```bash
   cp templates/<template>/agent-setup/<file> <repo-path>/<file>
   ```

9. If any files were updated, bump `template_version` in `.octo/graph.yaml` to the current
   template version using Python:
   ```python
   # Read graph.yaml, find the node entry for this repo by name, update template_version
   ```

10. Confirm what was updated (or skipped) and remind the user to commit the changes in the target repo.
