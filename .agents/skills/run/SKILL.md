---
name: run
description: >
  Run a task end-to-end: spawn the agent, monitor progress, collect results, retry on crash.
  Use when user says "/run <id>", "run this task", "check on <id>", "what happened to <id>", "execute <id>",
  "is <id> done", or wants to resume/retry a running or failed task.
---

# Run

Drives a task through its full lifecycle. Reads current state and takes the appropriate action —
spawn, tail, crash-recover, or advance to the next step — without requiring the user to
call separate skills.

## Steps

### 1. Resolve task

If an id is given, read `.octo/tasks/<id>.md`.

If no id is given, list all `.octo/tasks/*.md` files where `status` is `pending` or `running`
and ask the user to choose one.

Parse from the task file:
- Frontmatter: `id`, `title`, `status`
- `## Steps` section: parse the YAML list into step objects, each with:
  `step`, `repo`, `branch`, `task`, `done_when`, and optionally `depends_on`

Determine the octo root (the directory containing `.octo/`): use the current working directory.

### 2. Find the active step

Iterate through steps in order. For each step, check `.octo/runs/<id>/<step>/result.md`:

- `result.md` with `status: success` → step is complete, move to next
- No `result.md` and no `.octo/runs/<id>/<step>/pid` → this is the next pending step — **stop here**
- `pid` exists but no `result.md` → step is in-flight or crashed — **stop here**
- `result.md` with `status: failed` → step failed and needs retry — **stop here**

If every step has `status: success` in its result.md:
  - Update task frontmatter: `status: success`
  - Display a summary table of all steps with their PR URLs
  - Done

### 3. Check depends_on

If the active step has a `depends_on` value, verify that step's result.md has `status: success`.
If not, stop and tell the user: "Step `<active>` is waiting on `<dep>` (status: <status>)."

### 4. Resolve repo path

Read `OCTO_WORKSPACE` from `.octo/config`. The repo path is `$OCTO_WORKSPACE/<step.repo>`.
Verify the directory exists and contains `.git/`. If not found, scan all `$OCTO_WORKSPACE/*/`
subdirectories and match by directory name.

### 5. Determine action

**Case A — No run exists** (no pid file, no result.md at `.octo/runs/<id>/<step>/`):

Build the run directory path: `<octo-root>/.octo/runs/<id>/<step.step>/`

Generate `session.md` content using this template (substitute all `<...>` placeholders):

```
You are an autonomous coding agent working in <repo-path>.

## Task
<step.task>

## Done when
<step.done_when>

## Context
<task ## Context section, or "(none provided)">

## Repo state
Recent commits:
<git -C <repo-path> log --oneline -10>

Open octo branches in this repo:
<git -C <repo-path> branch --list 'octo/*' or "none">

## Heartbeat (required)
Signal liveness by writing the current Unix timestamp every 60 seconds:

  (
    while true; do
      date +%s > "<run-dir>/heartbeat"
      sleep 60
    done
  ) &
  HEARTBEAT_PID=$!

Start this background loop immediately before doing any work.
Kill it when done: kill $HEARTBEAT_PID 2>/dev/null || true

## Result (required)
When finished — success or failure — write the result file at:
  <run-dir>/result.md

Write EXACTLY this YAML frontmatter with no prose before the opening ---:

---
status: success
pr_url: https://github.com/...
summary: One paragraph describing what was done.
---

On failure write:
---
status: failed
summary: What went wrong and what was attempted.
---

## Constraints
- Max subagents: 5
- Timeout: 30 minutes
- No clarifying questions — use your best judgment
- On success: push branch `<step.branch>`, open PR, then write result.md
- On failure: write result.md with status=failed immediately, no retries
```

Write this content to `<repo-path>/session.md`.

Create the run directory: `mkdir -p <run-dir>`

Run:
```
bash scripts/spawn.sh <repo-path> <step.branch> <run-dir>
```

Parse the PID from the script output. Update task frontmatter: `status: running`.

Show the user:
- Step being run, repo, branch
- PID and log path

---

**Case B — Run exists and process is alive** (`kill -0 <pid>` succeeds):

Show the last 30 lines of `<run-dir>/log.txt`.

If `<run-dir>/heartbeat` exists, read it and show elapsed time since last heartbeat
(`$(( $(date +%s) - $(cat heartbeat) ))` seconds ago). Warn if > 5 minutes.

Tell the user the session is live and offer to show more log on request.

---

**Case C — Run exists, process is dead, no result.md**:

Auto-classify as crashed. Write to `<run-dir>/result.md`:
```
---
status: failed
summary: Session crashed — process exited without writing a result. See log for details.
---
```

Show the last 30 lines of `<run-dir>/log.txt`.

Ask: "Session crashed (PID <pid> is gone). Retry? (y/n)"

If yes: rename `<run-dir>/` to `<run-dir>-crashed-<timestamp>/` to archive it.
Then return to **Case A** (spawn a fresh run).

---

**Case D — result.md exists**:

Parse frontmatter from `<run-dir>/result.md`. Display status, PR URL (if present), and summary.

If `status: success`:
  - If more steps remain: show "Step complete — advancing to <next-step>" and loop back to step 2.
  - If this was the last step: update task frontmatter `status: success`. Show all-steps summary.

If `status: failed`:
  - Show the failure summary.
  - Ask: "Retry this step? (y/n)"
  - If yes: rename result.md to `result-failed-<timestamp>.md` and the pid file to `pid-failed-<timestamp>`.
    Then return to **Case A** (spawn a fresh run in the same run directory).
