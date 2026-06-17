#!/bin/bash
# demo-mode.sh — Toggle SonarQube demo-specific skills and agents on/off
# Usage: bash scripts/demo-mode.sh
#
# ON  → agents in .claude/agents/, skills enabled in settings.local.json
# OFF → agents moved to .claude/agents.disabled/, skills set to "off"
#
# State is detected from whether .claude/agents/ contains any .md files.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

AGENTS_DIR=".claude/agents"
AGENTS_DISABLED_DIR=".claude/agents.disabled"
SETTINGS=".claude/settings.local.json"

DEMO_SKILLS=(
  "arch-guard"
  "instance-report"
  "pre-push-review"
  "security-posture"
  "sonar-audit"
  "sonar-blitz"
  "sonar-fix"
  "sonar-onboard"
  "sonar-watch"
  "tech-debt-sprint"
)

AGENT_COUNT=$(ls "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')

if [[ "$AGENT_COUNT" -gt 0 ]]; then
  # ── Demo mode is ON → turn it OFF ────────────────────────────────────────
  echo "=== Demo mode: ON → disabling ==="

  mkdir -p "$AGENTS_DISABLED_DIR"
  for f in "$AGENTS_DIR"/*.md; do
    [[ -f "$f" ]] && mv "$f" "$AGENTS_DISABLED_DIR/"
  done
  MOVED=$(ls "$AGENTS_DISABLED_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "  Agents: moved $MOVED files → agents.disabled/"

  python3 - "$SETTINGS" "${DEMO_SKILLS[@]}" <<'EOF'
import json, sys, os
settings_file = sys.argv[1]
skills = sys.argv[2:]
data = {}
if os.path.exists(settings_file):
    with open(settings_file) as f:
        data = json.load(f)
overrides = data.get("skillOverrides", {})
for s in skills:
    overrides[s] = "off"
data["skillOverrides"] = overrides
with open(settings_file, "w") as f:
    json.dump(data, f, indent=2)
print(f"  Skills: set {len(skills)} to off in {settings_file}")
EOF

  echo ""
  echo "Demo mode OFF. Restart Claude Code for skill changes to take effect."

else
  # ── Demo mode is OFF → turn it ON ────────────────────────────────────────
  echo "=== Demo mode: OFF → enabling ==="

  if ls "$AGENTS_DISABLED_DIR"/*.md &>/dev/null 2>&1; then
    for f in "$AGENTS_DISABLED_DIR"/*.md; do
      [[ -f "$f" ]] && mv "$f" "$AGENTS_DIR/"
    done
    RESTORED=$(ls "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  Agents: restored $RESTORED files from agents.disabled/"
  else
    echo "  Agents: nothing in agents.disabled/ to restore"
  fi

  python3 - "$SETTINGS" "${DEMO_SKILLS[@]}" <<'EOF'
import json, sys, os
settings_file = sys.argv[1]
skills = sys.argv[2:]
if not os.path.exists(settings_file):
    print(f"  Skills: {settings_file} not found, nothing to change")
    sys.exit(0)
with open(settings_file) as f:
    data = json.load(f)
overrides = data.get("skillOverrides", {})
removed = [s for s in skills if s in overrides]
for s in skills:
    overrides.pop(s, None)
if overrides:
    data["skillOverrides"] = overrides
elif "skillOverrides" in data:
    del data["skillOverrides"]
with open(settings_file, "w") as f:
    json.dump(data, f, indent=2)
print(f"  Skills: removed overrides for {len(removed)} skills in {settings_file}")
EOF

  echo ""
  echo "Demo mode ON. Restart Claude Code for skill changes to take effect."
fi
