#!/bin/bash
# PostToolUse hook: Run SQAA analysis on edited/written files

if ! command -v sonar &> /dev/null; then
  exit 0
fi

# Read JSON from stdin and extract fields using sed (handles both compact and pretty-printed JSON)
stdin_data=$(cat)
tool_name=$(echo "$stdin_data" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

if [[ "$tool_name" != "Edit" ]] && [[ "$tool_name" != "Write" ]]; then
  exit 0
fi

file_path=$(echo "$stdin_data" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
  exit 0
fi

# Capture SQAA analysis output and pass it to Claude via additionalContext
output=$(sonar analyze sqaa --file "$file_path" --project sonar-solutions_Health-Dashboard 2>/dev/null)

# JSON-escape the output using awk (no external runtimes required)
escaped=$(printf '%s' "$output" | awk 'BEGIN{ORS=""} {gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "\\r"); if(NR>1) printf "\\n"; print}')

printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$escaped"

exit 0
