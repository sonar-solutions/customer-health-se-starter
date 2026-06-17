#!/bin/bash
file_path=$(cat | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -z "$file_path" ] && exit 0
command -v sonar &>/dev/null || exit 0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
project="$(bash "$REPO_ROOT/scripts/lib/resolve-project.sh" key)"
[ -z "$project" ] && exit 0

python3 - "$file_path" "$project" <<'EOF'
import json, subprocess, sys, os

file_path = sys.argv[1]
project = sys.argv[2]

try:
    r = subprocess.run(
        ["sonar", "api", "get",
         f"/api/issues/search?componentKeys={project}:{file_path}&resolved=false&ps=10"],
        capture_output=True, text=True, env=dict(os.environ), timeout=15
    )
    data = json.loads(r.stdout)
    total = data.get("total", 0)
    if total == 0:
        sys.exit(0)
    lines = [f"Open issues in {file_path} ({total} total):"]
    for i in data.get("issues", [])[:5]:
        sev = i.get("severity", "?")
        line = i.get("line", "?")
        msg = i.get("message", "")
        lines.append(f"  [{sev}] line {line} — {msg}")
    print(json.dumps({"systemMessage": "\n".join(lines)}))
except Exception:
    pass
EOF
