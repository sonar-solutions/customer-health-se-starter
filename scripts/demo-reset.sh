#!/bin/bash
# demo-reset.sh — Restore demo-ready state between demos
# Usage: bash scripts/demo-reset.sh [--se <name>]
#
# What this does:
#   1. Warns if uncommitted changes will be discarded
#   2. Resets to clean origin/main
#   3. Reports which intentional issues are present (no injection needed —
#      violations live permanently on main)
#   4. (--se) Resets the live-push branch for the given SE, closes/reopens PR
#
# After running: open a fresh Claude Code session

set -e

# Parse --se flag
SE_NAME=""
ARGS=("$@")
i=0
while [[ $i -lt ${#ARGS[@]} ]]; do
  if [[ "${ARGS[$i]}" == "--se" ]]; then
    SE_NAME=$(echo "${ARGS[$((i+1))]}" | tr '[:upper:]' '[:lower:]')
    i=$((i+2))
  else
    i=$((i+1))
  fi
done
if [[ -z "$SE_NAME" ]]; then
  SE_NAME=$(GITHUB_TOKEN="" gh api /user --jq '.login' 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
fi

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
echo "  demo/bad-state             — path traversal vuln, PR open (do not merge)"
echo "  demo/fixed-state           — all issues resolved, quality gate passing"
if [[ -n "$SE_NAME" ]]; then
  echo "  demo/live-push-${SE_NAME}  — arch violation ready, PR open, quality gate will fail on push"
fi

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


# Reset live-push branch (only if SE name resolved)
if [[ -n "$SE_NAME" ]]; then
  LIVE_BRANCH="demo/live-push-${SE_NAME}"
  echo ""
  echo "Resetting live-push branch for SE: $SE_NAME..."

  # Close open PR if any
  GITHUB_TOKEN="" gh pr close "$LIVE_BRANCH" --comment "Reset for next demo" 2>/dev/null || true

  # Force-push branch back to violation commit
  git push origin "refs/tags/demo/live-push-base:refs/heads/${LIVE_BRANCH}" --force 2>/dev/null || {
    echo "  Warning: could not force-push ${LIVE_BRANCH} (tag demo/live-push-base may be missing)"
  }

  echo "Live-push branch ready: ${LIVE_BRANCH}"
  echo "During the demo: git checkout ${LIVE_BRANCH} && git push origin ${LIVE_BRANCH}"
  echo "Then open a PR and run /sonar-watch once CI completes."
fi
