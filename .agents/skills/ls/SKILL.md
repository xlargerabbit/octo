---
name: ls
description: >
  List all tasks with status and step-level detail.Use when user says "/ls", "list tasks", "show tasks", "what's queued", "what's running".
---

# Ls

Lists all tasks from `.octo/tasks/` with live status derived from run artifacts.

## Steps

### 1. Collect tasks

Read all `.octo/tasks/*.md` files. For each, parse frontmatter (`id`, `title`, `status`, `created`)
and the `## Steps` section (count of steps, step names, repo targets).

### 2. Derive live status per task

For each task, check its run artifacts to get current reality (frontmatter may lag):

- For each step, check `.octo/runs/<id>/<step>/`:
  - `result.md` with `status: success` → step complete
  - `result.md` with `status: failed` → step failed
  - `pid` exists + `kill -0 <pid>` succeeds → step running
  - `pid` exists + process dead + no `result.md` → step crashed
  - Nothing → step pending

Summarise per task: `N/M steps complete`, current step state, active repo.

If a running step has a `heartbeat` file older than 5 minutes, flag it as
`⚠ stale heartbeat` — the agent may have crashed without writing result.md.

### 3. Display

Group tasks: **running** first, then **pending**, then **success**, then **failed**.

```
RUNNING
──────────────────────────────────────────────────────────────────
20260525-auth-flow      Implement JWT auth         step 1/2 · htmlshare
20260524-refactor       Extract service layer      step 1/1 · api-service  ⚠ stale heartbeat

PENDING
──────────────────────────────────────────────────────────────────
20260523-add-tests      Add integration tests      1 step · htmlshare

SUCCESS
──────────────────────────────────────────────────────────────────
20260520-init-repo      Initial scaffolding        1/1 · htmlshare
```

For running tasks with a live step, show the last heartbeat age in parentheses if available.

If `.octo/tasks/` is empty, say: "No tasks yet. Use /add to create one."
