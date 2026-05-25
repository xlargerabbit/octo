#!/usr/bin/env bash
# spawn.sh — checkout branch, launch claude headlessly, record pid
# Usage: bash scripts/spawn.sh <repo-path> <branch> <run-dir>
#
#   repo-path:  absolute path to target repo; session.md must already exist there
#   branch:     branch name to create (e.g. octo/20260525-auth-flow-step-1)
#   run-dir:    absolute path where pid and log.txt will be written
#               (e.g. .octo/runs/<task-id>/step-1)

set -euo pipefail

REPO_PATH="${1:?Usage: spawn.sh <repo-path> <branch> <run-dir>}"
BRANCH="${2:?Usage: spawn.sh <repo-path> <branch> <run-dir>}"
RUN_DIR="${3:?Usage: spawn.sh <repo-path> <branch> <run-dir>}"

SESSION_MD="${REPO_PATH}/session.md"

if [[ ! -f "$SESSION_MD" ]]; then
  echo "Error: session.md not found at $SESSION_MD" >&2
  exit 1
fi

if [[ ! -d "$REPO_PATH/.git" ]]; then
  echo "Error: $REPO_PATH is not a git repository" >&2
  exit 1
fi

mkdir -p "$RUN_DIR"

# Checkout branch in target repo
echo "Checking out branch '$BRANCH' in $REPO_PATH ..."
if ! git -C "$REPO_PATH" checkout -b "$BRANCH" 2>&1; then
  echo "Error: failed to create branch '$BRANCH' — it may already exist" >&2
  exit 1
fi

# Detect available AI CLI and set appropriate flags
if command -v copilot &>/dev/null; then
  AI_CLI="copilot"
  AI_FLAGS="--autopilot --allow-all --max-autopilot-continues 20"
elif command -v claude &>/dev/null; then
  AI_CLI="claude"
  AI_FLAGS="--dangerously-skip-permissions"
else
  echo "Error: neither 'copilot' nor 'claude' CLI found in PATH" >&2
  exit 1
fi

echo "Launching ${AI_CLI} for $BRANCH ..."
setsid timeout 1800 ${AI_CLI} ${AI_FLAGS} -p "$(cat "$SESSION_MD")" \
  > "${RUN_DIR}/log.txt" 2>&1 &
PID=$!

echo "$PID" > "${RUN_DIR}/pid"

echo "Session started: pid=${PID} branch=${BRANCH}"
echo "Log: ${RUN_DIR}/log.txt"
