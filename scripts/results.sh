#!/usr/bin/env bash
set -euo pipefail

# Usage: results.sh [<octo-root>]
# Defaults octo-root to current directory if not provided.

OCTO_ROOT="${1:-.}"
SESSIONS_DIR="${OCTO_ROOT}/.octo/runs"

parse_field() {
  local file="$1"
  local field="$2"
  awk '/^---/{found++; next} found==1 && /^'"$field"':/{sub(/^'"$field"':[[:space:]]*/,""); print; exit}' "$file"
}

RESULTS=$(find "${SESSIONS_DIR}" -name "result.md" 2>/dev/null || true)

if [ -z "${RESULTS}" ]; then
  echo "No completed sessions."
  exit 0
fi

printf "%-40s %-10s %-60s\n" "SESSION" "STATUS" "PR URL"
printf "%-40s %-10s %-60s\n" "-------" "------" "------"

while IFS= read -r result_file; do
  step_dir="$(dirname "${result_file}")"
  step="$(basename "${step_dir}")"
  task_id="$(basename "$(dirname "${step_dir}")")"
  session_id="${task_id}/${step}"
  status="$(parse_field "$result_file" "status")"
  pr_url="$(parse_field "$result_file" "pr_url")"
  summary="$(parse_field "$result_file" "summary")"

  printf "%-40s %-10s %-60s\n" "$session_id" "${status:-unknown}" "${pr_url:-null}"
  if [[ -n "$summary" ]]; then
    echo "  $summary"
  fi
done <<< "${RESULTS}"
