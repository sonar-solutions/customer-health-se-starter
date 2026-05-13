#!/bin/bash
if ! command -v sonar &> /dev/null; then
  exit 0
fi

output=$(sonar hook claude-post-tool-use --project sonar-solutions_Health-Dashboard 2>&1)

if echo "$output" | grep -qi "no issues found"; then
  echo "SonarQube SQAA: ✅ no issues found"
elif echo "$output" | grep -qE "found [0-9]+ issue"; then
  count=$(echo "$output" | grep -oE "[0-9]+ issue" | grep -oE "^[0-9]+")
  echo "SonarQube SQAA: ❌ ${count} issue(s) found — review required"
  echo "$output"
else
  echo "$output"
fi
