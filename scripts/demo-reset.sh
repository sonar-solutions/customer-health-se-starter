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

# Files generated live during the workshop's Generate beat.
# These MUST NOT be tracked on main — if they are, Claude finds the file
# already exists during the demo and the "watch the AI create this" beat
# breaks. The safety check below verifies they're absent after reset.
DEMO_GENERATION_FILES=(
  "frontend/src/hooks/useProjectMetrics.ts"
)

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

# 2a. Sanity check: verify no demo-generation file leaked onto main.
for f in "${DEMO_GENERATION_FILES[@]}"; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    echo ""
    echo "ERROR: $f is tracked on main but should not be."
    echo "  This file is created live by Claude during the workshop's Generate beat."
    echo "  Fix:  git rm $f && git commit -m 'revert(demo): unstage live-demo file' && git push"
    echo ""
    exit 1
  fi
done

echo ""
echo "Intentional issues confirmed present on main:"
echo "  backend/app/clients/sonarqube_client.py  — hardcoded api_key          (python:S6418 — Security)"
echo "  backend/app/services/scoring.py           — high cognitive complexity  (python:S3776 — Code Smell)"
echo "  backend/requirements.txt                  — pytest==8.2.0              (SCA — CVE-2025-71176)"
echo "  frontend/src/services/api.ts              — ReDoS-vulnerable regex     (typescript:S5852 — Security)"
echo "  frontend/src/hooks/useHealthScore.ts      — empty catch swallows error (typescript:S2486 — Bug)"
echo "  frontend/package.json                     — caniuse-lite (SCA — prohibited license)"

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


# Clean up stale SonarQube Cloud PR analyses
echo ""
echo "Cleaning up stale SonarQube PR analyses..."
SONAR_HOST="$(bash "$REPO_ROOT/scripts/lib/resolve-project.sh" url)"
SONAR_PROJECT="$(bash "$REPO_ROOT/scripts/lib/resolve-project.sh" key)"

if [[ -z "${SONAR_TOKEN:-}" ]]; then
  echo "  Skipping: SONAR_TOKEN not set"
else
  PR_KEYS=$(curl -sf -u "${SONAR_TOKEN}:" \
    "${SONAR_HOST}/api/project_pull_requests/list?project=${SONAR_PROJECT}" \
    | python3 -c "
import json,sys
prs = json.load(sys.stdin).get('pullRequests', [])
for pr in prs:
    print(pr['key'])
" 2>/dev/null || true)

  if [[ -z "$PR_KEYS" ]]; then
    echo "  No stale PR analyses to remove."
  else
    while IFS= read -r pr_key; do
      [[ -z "$pr_key" ]] && continue
      if curl -sf -X POST -u "${SONAR_TOKEN}:" \
        "${SONAR_HOST}/api/project_pull_requests/delete" \
        -d "project=${SONAR_PROJECT}&pullRequest=${pr_key}" > /dev/null 2>&1; then
        echo "  Deleted PR analysis #${pr_key}"
      else
        echo "  Warning: could not delete PR analysis #${pr_key}"
      fi
    done <<< "$PR_KEYS"
  fi
fi

# Close SonarQube Remediation Agent PRs and delete their branches
echo ""
echo "Closing SonarQube Remediation Agent PRs..."
SQRA_PRS=$(GITHUB_TOKEN="" gh pr list --author "app/sonarqube-agent" --state open --json number,headRefName \
  --jq '.[] | "\(.number) \(.headRefName)"' 2>/dev/null || true)
if [[ -z "$SQRA_PRS" ]]; then
  echo "  No SQRA PRs to close."
else
  while IFS=' ' read -r pr_num branch_name; do
    [[ -z "$pr_num" ]] && continue
    GITHUB_TOKEN="" gh pr close "$pr_num" --comment "Reset for next demo" 2>/dev/null \
      && echo "  Closed PR #${pr_num} (${branch_name})" \
      || echo "  Warning: could not close PR #${pr_num}"
    git push origin --delete "$branch_name" 2>/dev/null \
      && echo "  Deleted branch ${branch_name}" || true
  done <<< "$SQRA_PRS"
fi

# Refresh demo/bad-state PR on GitHub
echo ""
echo "Refreshing demo/bad-state PR..."
BAD_STATE_PR=$(GITHUB_TOKEN="" gh pr list --head demo/bad-state --state open --json number --jq '.[0].number' 2>/dev/null || true)
if [[ -n "$BAD_STATE_PR" ]]; then
  GITHUB_TOKEN="" gh pr close "$BAD_STATE_PR" --comment "Reset for next demo" \
    && echo "  Closed PR #${BAD_STATE_PR}" || echo "  Warning: could not close PR #${BAD_STATE_PR}"
fi
sleep 3

GITHUB_TOKEN="" gh pr create \
  --base main \
  --head demo/bad-state \
  --title "feat: add account export endpoint" \
  --body "$(cat <<'PRBODY'
## Summary

Adds a `GET /api/export` endpoint that exports account data to a JSON file.

## SonarQube Will Find

- **Path traversal vulnerability** — `filename` query parameter is used directly in `os.path.join()` without sanitization. An attacker could write outside the intended export directory.
- Existing issues on the branch: token in query param, localStorage hotspot, cognitive complexity, missing error state, vulnerable deps (requests, lodash)

## Demo Flow

1. Show this PR — quality gate should fail on the path traversal finding
2. Use `issue-fixer` or `/sonar-fix` to remediate
3. Compare with `demo/fixed-state` where all issues are resolved

🤖 Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)" && echo "  PR reopened from demo/bad-state" || echo "  Warning: could not reopen PR"

# Confirm CI was triggered for the new PR
echo "  Waiting for CI trigger..."
sleep 5
RUN_URL=$(GITHUB_TOKEN="" gh run list --branch demo/bad-state --workflow ci.yml --limit 1 --json url,status --jq '.[0] | "\(.status)  \(.url)"' 2>/dev/null || true)
if [[ -n "$RUN_URL" ]]; then
  echo "  CI run: $RUN_URL"
  echo "  SonarQube analysis will be ready in ~2 min."
else
  echo "  Warning: CI run not detected — check Actions tab manually."
fi

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
  echo "Then open a PR and check the quality gate in SonarQube Cloud once CI completes."
fi
