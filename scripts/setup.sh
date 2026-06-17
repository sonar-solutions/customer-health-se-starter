#!/bin/bash
# setup.sh — one-time onboarding for an SE adopting this demo repo.
#
# Does three things in order:
#   1. Creates a private GitHub repo under your account, pushes all demo branches + tag
#   2. Creates your SonarCloud project, bound to that GitHub repo (key = <gh-user>_<repo-slug>)
#   3. Opens the demo/bad-state PR and creates your live-push branch (via demo-reset.sh)
#
# Usage:
#   bash scripts/setup.sh [--name "<Project Name>"] [--repo <repo-name>] [--url <sonar-host>]
#
# Defaults:
#   --name  "Customer Health Scorecard"
#   --repo  derived from name slug  (e.g. "customer-health-scorecard")
#   --url   https://sonarcloud.io   (pass e.g. https://sc-staging.io for staging)
#
# GitHub org/user and SonarCloud org are both read from your gh auth login.
# SonarCloud project key = <gh-username>_<repo-slug>
#
# Requires:
#   - SONAR_TOKEN (or --token): SonarCloud token with Create Projects + Execute Analysis
#   - gh auth login already done

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
PROPS="$REPO_ROOT/sonar-project.properties"

SONAR_URL="$(bash "$REPO_ROOT/scripts/lib/resolve-project.sh" url)"
NAME=""
REPO_SLUG=""
TOKEN="${SONAR_TOKEN:-}"
RUN_SCAN="ask"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)   NAME="$2"; shift 2 ;;
    --repo)   REPO_SLUG="$2"; shift 2 ;;
    --url)    SONAR_URL="$2"; shift 2 ;;
    --token)  TOKEN="$2"; shift 2 ;;
    --scan)   RUN_SCAN="yes"; shift ;;
    --no-scan) RUN_SCAN="no"; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# --- Resolve GitHub identity -------------------------------------------------
echo "Resolving GitHub identity..."
GH_USER="$(GITHUB_TOKEN="" gh api /user --jq '.login' 2>/dev/null)"
if [[ -z "$GH_USER" ]]; then
  echo "ERROR: could not resolve GitHub user. Run: gh auth login" >&2
  exit 1
fi
echo "  GitHub user: $GH_USER"

# --- Derive names from GitHub user + project name ----------------------------
if [[ -z "$NAME" ]]; then
  read -r -p "Project name [Customer Health Scorecard]: " NAME
  NAME="${NAME:-Customer Health Scorecard}"
fi
if [[ -z "$REPO_SLUG" ]]; then
  REPO_SLUG="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"
fi

# SonarCloud org = GitHub username; key = <gh-user>_<repo-slug>
SONAR_ORG="$GH_USER"
SONAR_KEY="${GH_USER}_${REPO_SLUG}"
GH_REPO="${GH_USER}/${REPO_SLUG}"

# --- SonarCloud token --------------------------------------------------------
if [[ -z "$TOKEN" ]]; then
  echo ""
  echo "No SONAR_TOKEN found. Generate one at:"
  echo "  $SONAR_URL → My Account → Security → Generate Token"
  echo "  (needs Create Projects + Execute Analysis on org '$SONAR_ORG')"
  read -r -s -p "Paste token: " TOKEN; echo
fi

echo ""
echo "=== Setup plan ==="
echo "  GitHub repo    : https://github.com/$GH_REPO"
echo "  SonarCloud org : $SONAR_ORG"
echo "  Project key    : $SONAR_KEY"
echo "  Sonar URL      : $SONAR_URL"
echo ""

# --- 1. GitHub repo ----------------------------------------------------------
echo "Creating GitHub repo $GH_REPO..."
if GITHUB_TOKEN="" gh repo view "$GH_REPO" &>/dev/null; then
  echo "  already exists — skipping creation."
else
  GITHUB_TOKEN="" gh repo create "$GH_REPO" \
    --private \
    --description "SonarQube + Claude Code SE demo — $NAME" \
    && echo "  created."
fi

echo "Re-pointing origin → https://github.com/$GH_REPO.git"
git remote set-url origin "https://github.com/$GH_REPO.git"

echo "Pushing demo branches..."
for branch in main demo/bad-state demo/fixed-state; do
  git push origin "$branch" --quiet \
    && echo "  pushed $branch" \
    || echo "  Warning: could not push $branch"
done

echo "Pushing demo/live-push-base tag..."
git push origin refs/tags/demo/live-push-base --quiet \
  && echo "  pushed tag demo/live-push-base" \
  || echo "  Warning: could not push tag (it may already exist)"

# --- 2. SonarCloud project ---------------------------------------------------
echo ""
echo "Validating SonarCloud token..."
valid="$(curl -s -u "$TOKEN:" "$SONAR_URL/api/authentication/validate" | tr -d ' ')"
if [[ "$valid" != *'"valid":true'* ]]; then
  echo "ERROR: token failed validation. Check the token and its permissions." >&2
  exit 1
fi
echo "  token OK"

echo "Creating SonarCloud project '$SONAR_KEY' (skips if it already exists)..."
create_resp="$(curl -s -u "$TOKEN:" -X POST \
  "$SONAR_URL/api/projects/create" \
  --data-urlencode "organization=$SONAR_ORG" \
  --data-urlencode "project=$SONAR_KEY" \
  --data-urlencode "name=$NAME" || true)"

if echo "$create_resp" | grep -q '"project"'; then
  echo "  created."
elif echo "$create_resp" | grep -qi "key already exists"; then
  echo "  already exists — reusing."
else
  echo "WARNING: unexpected response from project create:" >&2
  echo "  $create_resp" >&2
  echo "  Continuing — verify the project exists in SonarCloud." >&2
fi

# --- Write sonar-project.properties (single source of truth) -----------------
echo "Updating sonar-project.properties..."
tmp="$(mktemp)"
sed -E \
  -e "s|^sonar\.projectKey[[:space:]]*=.*|sonar.projectKey=$SONAR_KEY|" \
  -e "s|^sonar\.projectName[[:space:]]*=.*|sonar.projectName=$NAME|" \
  -e "s|^sonar\.organization[[:space:]]*=.*|sonar.organization=$SONAR_ORG|" \
  -e "s|^sonar\.host\.url[[:space:]]*=.*|sonar.host.url=$SONAR_URL|" \
  "$PROPS" > "$tmp"
if ! grep -q "^sonar\.host\.url" "$tmp"; then
  echo "sonar.host.url=$SONAR_URL" >> "$tmp"
fi
mv "$tmp" "$PROPS"
echo "  done."

# --- 3. PR + live-push branch (via demo-reset.sh) ----------------------------
echo ""
echo "Setting up demo PRs and live-push branch..."
# Export token so demo-reset.sh can authenticate
export SONAR_TOKEN="$TOKEN"
bash "$REPO_ROOT/scripts/demo-reset.sh" --se "$GH_USER"

# --- Optional first scan -----------------------------------------------------
if [[ "$RUN_SCAN" == "ask" ]]; then
  read -r -p "Run a first SonarCloud scan now to populate the project? (y/N) " a
  [[ "$a" =~ ^[Yy]$ ]] && RUN_SCAN="yes" || RUN_SCAN="no"
fi
if [[ "$RUN_SCAN" == "yes" ]]; then
  if command -v sonar-scanner >/dev/null 2>&1; then
    echo "Running sonar-scanner..."
    sonar-scanner -Dsonar.token="$TOKEN"
  else
    echo "sonar-scanner not on PATH — skipping. Install it, then run:"
    echo "  sonar-scanner -Dsonar.token=\$SONAR_TOKEN"
  fi
fi

# --- Env vars to export ------------------------------------------------------
echo ""
echo "=== Add these to ~/.zshrc (or ~/.bashrc), then restart your shell ==="
echo ""
echo "export SONAR_TOKEN=$TOKEN"
echo "export SONARQUBE_ORG=$SONAR_ORG"
echo "export SONARQUBE_PROJECT_KEY=$SONAR_KEY"
if [[ "$SONAR_URL" != "https://sonarcloud.io" ]]; then
  echo "export SONARQUBE_URL=$SONAR_URL"
fi
echo ""

cat <<'EOF'
=== Next ===
1. Export the vars above and restart your shell.
2. Open a fresh Claude Code session in this repo.
3. The SessionStart hook should print issue counts + "MCP: ✓ connected".
   If MCP shows ✗, confirm your env vars are exported and run /mcp to diagnose.
EOF
