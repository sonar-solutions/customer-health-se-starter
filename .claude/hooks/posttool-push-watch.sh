#!/bin/bash
# PostToolUse hook: Detect git push and prompt /sonar-watch if SonarQube CI check exists

# Only fire on Bash tool calls
stdin_data=$(cat)
tool_name=$(echo "$stdin_data" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

# Only fire when the command is a git push
command=$(echo "$stdin_data" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if ! echo "$command" | grep -q "git push"; then
  exit 0
fi

# Check for an open PR
pr_json=$(GITHUB_TOKEN="" gh pr view --json number,headRefName 2>/dev/null)
if [[ -z "$pr_json" ]] || ! echo "$pr_json" | grep -q '"number"'; then
  exit 0
fi
pr_number=$(echo "$pr_json" | sed -n 's/.*"number"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)

# Check for a SonarQube CI check
checks=$(GITHUB_TOKEN="" gh pr checks 2>/dev/null)
if [[ -z "$checks" ]]; then
  exit 0
fi
if ! echo "$checks" | grep -qi "sonar"; then
  exit 0
fi

# Return prompt to Claude
msg="git push detected. SonarQube CI check found on PR #${pr_number}. Run /sonar-watch to check the quality gate once CI completes."
escaped=$(printf '%s' "$msg" | awk 'BEGIN{ORS=""} {gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "\\r"); if(NR>1) printf "\\n"; print}')
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$escaped"
exit 0
