---
name: new-repo
description: >
  Scaffolds a new managed repo from a template. The new repo is auto-discovered
  by workspace scan — no manual registration needed.
  Use when the user wants to create a new project or service under octo management.
---

# New Repo

## Steps

1. List available templates by reading the `templates/` directory. For each subdirectory,
   read its `template.json` and display the template name and description:
   - `generic` — Blank repo with agent setup
   - `go-service` — Go HTTP service
   - `next-app` — Next.js web application

2. Read `OCTO_WORKSPACE` from `.octo/config`. Show the user where new repos will live by default.

3. Ask the user for the following:
   - **Template**: which template to use (from the list above)
   - **Project name**: short identifier used as the repo name and substituted as `{{PROJECT_NAME}}`
   - **Target path**: absolute path where the new repo should be created (default: `$OCTO_WORKSPACE/<name>`). `~` is supported.
   - **Description**: one-sentence description of the project (substituted as `{{DESCRIPTION}}` where applicable)

4. Confirm the choices before proceeding:
   ```
   Template:     <template>
   Project name: <name>
   Target path:  <path>
   Description:  <description>
   ```
   Ask: "Proceed with scaffold? (yes/no)"

5. Run the scaffold script from the octo root:
   ```
   bash scripts/scaffold.sh <template> <name> <path> .
   ```
   Capture and display the output. If the script exits non-zero, report the error and stop.

   The script copies template files, substitutes variables, runs `git init`, makes an initial
   commit, and adds a metadata entry to `.octo/graph.yaml`.

6. Confirm success and show next steps:
   - Repo created at `<path>`
   - Auto-discoverable via workspace scan (no registration step required)
   - Metadata recorded in `.octo/graph.yaml`
   - Suggested next steps:
     - Open the new repo: `claude <path>`
     - Queue work for it: `/add`
     - Review the generated `CLAUDE.md` and customise as needed
