# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Octo is an orchestration control plane for managing multiple repositories from a single Claude Code session. You queue tasks here; autonomous Claude sessions execute them in target repos, push branches, open PRs, and report back.

## Key Commands

There are no build, lint, or test steps in this repo. All operations are skill invocations or direct script calls.

| Command                 | What it does                                                                  |
| ----------------------- | ----------------------------------------------------------------------------- |
| `/add`                  | Queue a new task (single-step or multi-step across repos)                     |
| `/run <id>`             | Spawn, monitor, collect results, and retry — full lifecycle in one command    |
| `/ls`                   | Show all tasks grouped by status with step-level detail                       |
| `/new-repo`             | Scaffold a new repo from a template (auto-discovered, no registration needed) |
| `/sync-template <repo>` | Diff a managed repo's agent-setup against the current template version        |

Low-level scripts (called by the skills above, but usable directly):

```bash
bash scripts/spawn.sh <repo-path> <branch> <run-dir>   # Checkout branch, launch agent, record pid
bash scripts/scaffold.sh <template> <name> <path> .    # Copy template, substitute vars, git init
```

## Architecture

### Three Layers

**Control plane (this repo)** — Where you interact. Holds tasks, run artifacts, node metadata, and skills.

**Orchestration scripts** (`scripts/`) — Shell scripts that do the mechanical work: branching, launching agents headlessly, scaffolding repos.

**Managed repos** (external) — Target repos where autonomous agents execute tasks. Each gets a `session.md` (the task prompt) and writes a `result.md` to the control plane on completion.

### Data Flow

```
/add      →  .octo/tasks/<id>.md                     (status: pending)
/run <id> →  target repo: branch octo/<id>-step-N, session.md written, agent launched
             .octo/runs/<id>/step-N/pid + log.txt    (status: running)
             agent writes heartbeat every 60s
agent done → agent writes .octo/runs/<id>/step-N/result.md, opens PR
/run <id> →  detects result.md, advances to next step or marks task complete
```

### Key Paths

- `.octo/config` — `OCTO_WORKSPACE=<path>` — workspace root; all git subdirs are auto-discovered nodes
- `.octo/graph.yaml` — Optional node metadata (template name, version, cross-repo relationships). Omit entries for repos that need no tracking.
- `.octo/tasks/` — One `.md` file per task (frontmatter: id, title, status, created; body: steps list + context)
- `.octo/runs/<id>/step-N/` — Per-step run artifacts: `pid`, `heartbeat`, `log.txt`, `result.md`
- `.agents/skills/` — Custom skills (each skill is a `SKILL.md` in its own subdirectory); `.claude/skills/` mirrors these as symlinks so Claude Code picks them up
- `templates/` — Repo scaffolds (`generic`, `go-service`, `next-app`); each has `files/`, `agent-setup/`, and `template.json`

### Task Format

```markdown
---
id: 20260525-auth-flow
title: Implement JWT auth end to end
status: pending | running | success | failed
created: 2026-05-25
---

## Steps

- step: step-1
  repo: api-service
  branch: octo/20260525-auth-flow-step-1
  task: |
  Add JWT middleware and /auth/token endpoint.
  done_when: |
  Tests pass. Endpoint returns 200 with signed JWT.

- step: step-2
  repo: web-app
  branch: octo/20260525-auth-flow-step-2
  depends_on: step-1
  task: |
  Wire login form to /auth/token, store token in httpOnly cookie.
  done_when: |
  Login flow works end to end in the browser.

## Context

Auth is missing. Tracked in Linear AUTH-42.
```

Single-step tasks have one entry under `## Steps` with no `depends_on`.
`depends_on` enforces sequencing: `/run` will not spawn a step until its dependency has `status: success` in its `result.md`.

### Run Directory Layout

```
.octo/runs/<task-id>/
  step-1/
    pid            ← PID of the spawned claude process
    heartbeat      ← Unix timestamp written by agent every 60s; staleness > 5m signals a crash
    log.txt        ← stdout/stderr from the agent
    result.md      ← written by agent on completion (YAML: status, pr_url, summary)
  step-2/
    ...
```

The task file (`.octo/tasks/<id>.md`) is the spec and never changes after creation.
Runtime state lives exclusively in `.octo/runs/` and is derived from file existence and process liveness.

### Template Substitution

Templates use `{{VARIABLE}}` placeholders. `scaffold.sh` replaces them via Python. Each template's `agent-setup/` directory provides the `CLAUDE.md` and `.claude/settings.json` that autonomous agents in scaffolded repos will use.

## Installed Skills

Skills live in `.agents/skills/<name>/SKILL.md`. Each must also have a symlink in `.claude/skills/<name>` pointing to `../../.agents/skills/<name>` so Claude Code picks it up.

**To add a skill:**

```bash
mkdir .agents/skills/<name>
# write .agents/skills/<name>/SKILL.md
ln -s ../../.agents/skills/<name> .claude/skills/<name>
```

**To delete a skill:** remove the directory from `.agents/skills/` and the symlink from `.claude/skills/`.

### Current skills

| Skill           | Description                                               |
| --------------- | --------------------------------------------------------- |
| `add`           | Queue a task (single or multi-step, single or multi-repo) |
| `run`           | Full session lifecycle: spawn, monitor, collect, retry    |
| `ls`            | List all tasks with live step-level status                |
| `new-repo`      | Scaffold and auto-discover a new managed repo             |
| `sync-template` | Diff and optionally update a repo's agent-setup           |

#### Other skills

| Skill                        | Description                                                    |
| ---------------------------- | -------------------------------------------------------------- |
| `caveman` / `caveman-commit` | Token-efficient communication and terse commit messages        |
| `tinyspec` plugin            | Specification workflow (configured in `.claude/settings.json`) |
