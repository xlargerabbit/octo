# Project Context

This is a managed repo scaffolded by octo. It may receive autonomous session tasks delivered via `session.md`.

## Session Task Handling

If a file named `session.md` exists at the repo root:

1. Read `session.md` immediately at the start of any session.
2. Execute the task described autonomously — no clarifying questions, use judgment.
3. On completion (success or failure), write `result.md` to the path specified in the session constraints using exactly this format:

```
status: success | failed
pr_url: <url or null>
summary: <one paragraph>
```

Do not leave `result.md` unwritten. If an unrecoverable error occurs, write `result.md` with `status: failed` and a summary of what went wrong, then exit.

## General Conventions

- Commit small, logical units of work with clear commit messages.
- Do not commit directly to `main`. Work on the branch that was checked out when the session started.
- Push the branch and open a PR when the task is complete and all checks pass.
