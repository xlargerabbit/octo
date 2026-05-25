# {{PROJECT_NAME}}

{{DESCRIPTION}}

## Project context

- **Module path**: `{{MODULE_PATH}}`
- **Language**: Go 1.22
- **Layout**: standard Go project layout
  - `cmd/` — main packages and entrypoints
  - `internal/` — private application code
  - `pkg/` — exported library packages (if any)
  - `bin/` — compiled binaries (gitignored)

## Conventions

- All HTTP handlers live in packages under `internal/`; `cmd/main.go` wires them up
- Use `log/slog` for structured logging (available in Go 1.21+)
- Environment variables for configuration; never hardcode secrets
- Run `go vet ./...` and `go test ./...` before committing
- Binary name matches project name; build with `go build -o bin/{{PROJECT_NAME}} ./cmd/`

## Autonomous session instructions

If a file named `session.md` is present at the repository root, read it immediately and execute the task described there autonomously. Do not ask clarifying questions — use your best judgment and proceed. When the task is complete (or if it fails), write `result.md` to the repository root using exactly this schema:

```
status: success | failed
pr_url: <url or null>
summary: <one paragraph>
```
