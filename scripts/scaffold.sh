#!/usr/bin/env bash
set -euo pipefail

# Usage: scaffold.sh <template-name> <project-name> <target-path> <octo-root>

TEMPLATE_NAME="${1:-}"
PROJECT_NAME="${2:-}"
TARGET_PATH="${3:-}"
OCTO_ROOT="${4:-}"

if [[ -z "$TEMPLATE_NAME" || -z "$PROJECT_NAME" || -z "$TARGET_PATH" || -z "$OCTO_ROOT" ]]; then
  echo "Usage: $0 <template-name> <project-name> <target-path> <octo-root>" >&2
  exit 1
fi

TEMPLATE_DIR="$OCTO_ROOT/templates/$TEMPLATE_NAME"

# Step 2: Validate template exists
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Error: template '$TEMPLATE_NAME' not found at $TEMPLATE_DIR" >&2
  exit 1
fi

# Step 3: Expand ~ in target-path
TARGET_PATH="${TARGET_PATH/#\~/$HOME}"
PARENT_DIR="$(dirname "$TARGET_PATH")"
if [[ ! -d "$PARENT_DIR" ]]; then
  echo "Error: parent directory '$PARENT_DIR' does not exist" >&2
  exit 1
fi

# Step 4: Copy template files to target path
if [[ -d "$TEMPLATE_DIR/files" ]]; then
  cp -r "$TEMPLATE_DIR/files/" "$TARGET_PATH/"
fi

# Step 5: Substitute {{PROJECT_NAME}} and other vars from template.json in all files
TEMPLATE_JSON="$TEMPLATE_DIR/template.json"

find "$TARGET_PATH" -type f | while read -r file; do
  # Always substitute PROJECT_NAME
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$file"
  else
    sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$file"
  fi

  # Substitute additional vars from template.json if file exists
  if [[ -f "$TEMPLATE_JSON" ]]; then
    # Extract vars array from template.json using python3
    VARS=$(python3 -c "
import json, sys
with open('$TEMPLATE_JSON') as f:
    data = json.load(f)
vars_list = data.get('vars', [])
# Print each var that is not PROJECT_NAME (already handled above)
for v in vars_list:
    if v != 'PROJECT_NAME':
        print(v)
" 2>/dev/null || true)

    # For each additional var, check if an env var with that name is set and substitute
    if [[ -n "$VARS" ]]; then
      while IFS= read -r var; do
        [[ -z "$var" ]] && continue
        val="${!var:-}"
        if [[ -n "$val" ]]; then
          if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s/{{$var}}/$val/g" "$file"
          else
            sed -i "s/{{$var}}/$val/g" "$file"
          fi
        fi
      done <<< "$VARS"
    fi
  fi
done

# Step 6: Copy agent-setup into target path root
if [[ -d "$TEMPLATE_DIR/agent-setup" ]]; then
  cp -r "$TEMPLATE_DIR/agent-setup/." "$TARGET_PATH/"
fi

# Step 7: git init target path
git init "$TARGET_PATH"

# Step 8: Initial commit
git -C "$TARGET_PATH" add -A
git -C "$TARGET_PATH" commit -m "chore: init from octo template $TEMPLATE_NAME"

# Step 9: Append new repo entry to graph.yaml
GRAPH="$OCTO_ROOT/.octo/graph.yaml"
TODAY=$(date +%Y-%m-%d)

TEMPLATE_VERSION=$(python3 -c "
import json
try:
    with open('$TEMPLATE_DIR/template.json') as f:
        print(json.load(f).get('version', ''))
except Exception:
    print('')
" 2>/dev/null || true)

python3 -c "
import sys, re

graph_path = '$GRAPH'
project = '$PROJECT_NAME'
template = '$TEMPLATE_NAME'
version = '${TEMPLATE_VERSION}'
added = '$TODAY'

try:
    with open(graph_path) as f:
        content = f.read()
except FileNotFoundError:
    content = 'nodes:\n'

# Only append if the node doesn't already exist
if re.search(r'^  ' + re.escape(project) + r':', content, re.MULTILINE):
    sys.exit(0)

entry = f'\n  {project}:\n    template: {template}\n'
if version:
    entry += f'    template_version: \"{version}\"\n'
entry += f'    added: \"{added}\"\n'

with open(graph_path, 'a') as f:
    f.write(entry)
"

# Step 10: Print scaffold complete
echo "Scaffold complete. New repo created at: $TARGET_PATH"
