#!/bin/bash
if ! command -v sonar &> /dev/null; then
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
PROJECT="$(bash "$REPO_ROOT/scripts/lib/resolve-project.sh" key)"

output=$(cat | sonar hook claude-post-tool-use --project "$PROJECT" 2>&1)

if echo "$output" | grep -qi "no issues found"; then
  echo "SonarQube SQAA: ✅ no issues found"
elif echo "$output" | grep -qE "found [0-9]+ issue"; then
  count=$(echo "$output" | grep -oE "[0-9]+ issue" | grep -oE "^[0-9]+")
  echo "SonarQube SQAA: ❌ ${count} issue(s) found — review required"
  echo "$output"
else
  echo "$output"
fi
