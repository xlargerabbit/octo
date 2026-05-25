---
name: add
description: >
  Create a new task — single-step or multi-step across one or more repos.
  Use when the user wants to queue work: "add a task", "I want to build X", "/add", "implement", "fix bug", "refactor", "build a feature".
---

# Add

Interviews the user and writes a task file to `.octo/tasks/<id>.md`.
A task has one or more steps; each step targets one repo with a clear done condition.

## Steps

### 1. Discover available repos

Read `.octo/config` to get `OCTO_WORKSPACE`. Scan `$OCTO_WORKSPACE/` for immediate subdirectories
containing `.git/`. Each is an available repo (name = directory name, path = full path).
Also read `.octo/graph.yaml` if it exists for any additional metadata.

### 2. Interview

Ask the user:
- **Title**: one-line description of the overall goal
- **Is this multi-step?** — does it span multiple sequential phases or repos? (yes/no)

If single-step, ask:
- Which repo (show discovered list)
- What the agent should do (task description)
- Done when: measurable, observable completion criteria

If multi-step, collect steps one at a time. For each step:
- Which repo (show list)
- Task description for this step
- Done when criteria for this step
- Does this step depend on the previous? (default yes — press enter to accept)

Continue collecting steps until the user says "done" or "that's it".

Then ask:
- **Context**: background and motivation (optional — press enter to skip)

### 3. Generate task ID

Format: `YYYYMMDD-<slug>` where slug is a 2–3 word kebab-case summary of the title.
Use today's date. Example: `20260525-auth-flow`.

### 4. Write `.octo/tasks/<id>.md`

Single-step example:
```markdown
---
id: 20260525-fix-login
title: Fix login redirect bug
status: pending
created: 2026-05-25
---

## Steps

- step: step-1
  repo: htmlshare
  branch: octo/20260525-fix-login-step-1
  task: |
    The login redirect sends users to /home instead of /dashboard after auth.
    Fix the redirect target in src/auth/callback.ts.
  done_when: |
    Login flow redirects to /dashboard. Existing tests pass.

## Context

Reported by QA. Affects all OAuth login paths.
```

Multi-step example (two repos):
```markdown
---
id: 20260525-auth-flow
title: Implement JWT auth end to end
status: pending
created: 2026-05-25
---

## Steps

- step: step-1
  repo: api-service
  branch: octo/20260525-auth-flow-step-1
  task: |
    Add JWT middleware and POST /auth/token endpoint.
  done_when: |
    Tests pass. Endpoint returns 200 with signed JWT for valid credentials.

- step: step-2
  repo: web-app
  branch: octo/20260525-auth-flow-step-2
  depends_on: step-1
  task: |
    Wire the login form to POST /auth/token. Store the token in an httpOnly cookie.
  done_when: |
    Login flow works end to end in the browser.

## Context

Auth is currently missing. Tracked in Linear AUTH-42.
```

### 5. Confirm

Show the task summary to the user:
- ID, title, number of steps, repo(s) targeted
- Command to execute: `/run <id>`
