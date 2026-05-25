# octo

Octo is an orchestration control plane for a solo operator managing multiple repos concurrently. You stay in one Claude Code session inside the octo repo, use skills to plan and queue work, then spawn autonomous Claude sessions that execute in target repos in the background — branching, coding, and opening PRs without your involvement. Results flow back as artifacts you can review at any time.

---

## Workspace Setup

Keep octo and your managed repos as sibling directories under a common workspace root:

```
~/workspace/
├── octo/              ← this repo (control plane)
├── api/               ← managed repo
└── web/               ← managed repo
```

Managed repos are registered in `.octo/registry.json`. The registry maps a short name to the absolute path of each repo. You can add repos manually or via the `new-repo` skill. When you run `spawn`, the path in the registry is used to locate the repo and create the feature branch.

---

## Skills

| Skill | What it does | When to use |
|---|---|---|
| `backlog-add` | Interviews you and writes a task spec to `.octo/backlog/<id>.md` | After discussing a requirement; turns the conversation into a queued item |
| `backlog-list` | Lists all backlog items grouped by status (pending → running → done/failed) | To see what is queued, in-flight, or finished |
| `spawn` | Branches the target repo, writes a session prompt, and launches a headless Claude process in the background | When you are ready to execute a pending backlog item |
| `results` | Reads all `result.md` artifacts from completed sessions, updates backlog status, and surfaces PR URLs and summaries | After sessions have run; collect outcomes and decide next steps |
| `new-repo` | Scaffolds a new repo from a template, runs `git init`, and registers it in the registry | When starting a new project or service under octo management |

---

## End-to-End Flow

1. **Discuss** the requirement with Claude Code in octo. No files yet — just thinking.
2. **`/backlog-add`** — skill interviews you (title, target repo, task spec, context, done-when criteria) and writes `.octo/backlog/<id>.md` with `status: pending`.
3. **`/spawn <id>`** — skill reads the backlog item, runs `scripts/spawn.sh` to create a feature branch in the target repo, writes `session.md` (the autonomous agent's prompt), launches `claude --dangerously-skip-permissions -p` as a background process, and updates the backlog item to `status: running`.
4. **Session runs autonomously** in the target repo — no user interaction. On success it pushes the branch, opens a PR, and writes `.octo/sessions/<id>/result.md`. On failure it writes `result.md` with `status: failed` and exits.
5. **`/results`** — skill scans all `result.md` files, updates backlog frontmatter, and prints a table of session IDs, titles, statuses, PR URLs, and summaries.
6. **Review** — open the PR URLs, merge or close, and decide what to queue next.

Multiple sessions run concurrently across different repos and branches. Octo is never blocked.

---

## Templates

Templates live in `templates/` and are used by `new-repo` / `scaffold.sh` to bootstrap managed repos with scaffolded source code and agent setup (`CLAUDE.md`, `.claude/settings.json`).

| Template | Description |
|---|---|
| `generic` | Blank repo with agent setup. No framework assumptions. Good starting point for any project type. |
| `go-service` | Go HTTP service with standard layout (`cmd/main.go`, `go.mod`). Supports `PROJECT_NAME`, `MODULE_PATH`, and `DESCRIPTION` substitution. |
| `next-app` | Next.js web application with App Router conventions (`package.json`, `next.config.js`). Supports `PROJECT_NAME` and `DESCRIPTION` substitution. |
