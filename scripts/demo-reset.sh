#!/bin/bash
# demo-reset.sh — Restore demo-ready state between demos
# Usage: bash scripts/demo-reset.sh
#
# What this does:
#   1. Warns if uncommitted changes will be discarded
#   2. Resets to clean origin/main
#   3. Reports which intentional issues are present (no injection needed —
#      violations live permanently on main)
#
# After running: open a fresh Claude Code session

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "=== Demo Reset ==="

# 1. Warn before discarding uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo ""
  echo "WARNING: You have uncommitted changes that will be discarded."
  echo "Continue? (y/N)"
  read -r CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted. No changes made."; exit 0; }
fi

# 2. Return to main and hard-reset to origin
echo "Resetting to origin/main..."
git checkout main 2>/dev/null || true
git fetch origin main --quiet
git reset --hard origin/main
git clean -fd --quiet

echo ""
echo "Intentional issues confirmed present on main:"
echo "  backend/app/clients/sonarqube_client.py  — token in query param       (Security Hotspot)"
echo "  backend/app/services/scoring.py           — high cognitive complexity  (Code Smell)"
echo "  backend/requirements.txt                  — requests==2.18.4           (SCA — CVE-2018-18074)"
echo "  frontend/src/services/api.ts              — token in localStorage      (Security Hotspot)"
echo "  frontend/src/hooks/useHealthScore.ts      — missing error state        (Bug)"
echo "  frontend/package.json                     — lodash@4.17.10             (SCA — CVE-2019-10744)"

echo ""
echo "Demo branches:"
echo "  demo/bad-state   — export endpoint with path traversal vuln (PR #1 open)"
echo "  demo/fixed-state — all issues resolved, quality gate passing"

echo ""
echo "Marking intentional issue files as modified for /pre-push-review..."
echo "" >> backend/app/clients/sonarqube_client.py
echo "" >> backend/app/services/scoring.py
echo "" >> backend/requirements.txt
echo "" >> frontend/src/services/api.ts
echo "" >> frontend/src/hooks/useHealthScore.ts
echo "" >> frontend/package.json

echo ""
echo "Reset complete."
echo "Open a fresh Claude Code session — the SessionStart hook will surface live issue counts."
echo "Then run: /pre-push-review"
