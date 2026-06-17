#!/bin/bash
# setup.sh — one-time onboarding for an SE adopting this demo repo.
#
# Creates YOUR OWN SonarQube project (so you can run your own PRs without
# touching anyone else's demo), points this repo at it, and tells you which
# env vars to export.
#
# Usage:
#   bash scripts/setup.sh --org <your-org> --name "<Project Name>" [--key <project-key>] [--url <host>]
#
# --url defaults to https://sonarcloud.io. Pass e.g. https://sc-staging.io for staging.
#
# Requires: a token with "Create Projects" + "Execute Analysis" on your org,
# exported as SONARCLOUD_DEMOS_TOKEN (or passed via --token).

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# Read URL default from resolver (env → properties → built-in default)
SONAR_URL="$(bash "$REPO_ROOT/scripts/lib/resolve-project.sh" url)"
ORG=""
NAME=""
KEY=""
TOKEN="${SONARCLOUD_DEMOS_TOKEN:-${SONAR_TOKEN:-}}"
RUN_SCAN="ask"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)    ORG="$2"; shift 2 ;;
    --name)   NAME="$2"; shift 2 ;;
    --key)    KEY="$2"; shift 2 ;;
    --url)    SONAR_URL="$2"; shift 2 ;;
    --token)  TOKEN="$2"; shift 2 ;;
    --scan)   RUN_SCAN="yes"; shift ;;
    --no-scan) RUN_SCAN="no"; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

cd "$REPO_ROOT"
PROPS="$REPO_ROOT/sonar-project.properties"

# --- Prompt for anything still missing ---------------------------------------
if [[ -z "$ORG" ]]; then
  read -r -p "SonarCloud organization key: " ORG
fi
if [[ -z "$NAME" ]]; then
  read -r -p "Project name [Customer Health Scorecard]: " NAME
  NAME="${NAME:-Customer Health Scorecard}"
fi
# Convention mirrors the original key (<org>_<slug>). Override with --key.
if [[ -z "$KEY" ]]; then
  SLUG="$(echo "$NAME" | tr ' ' '-' | tr -cd '[:alnum:]-_')"
  KEY="${ORG}_${SLUG}"
fi

if [[ -z "$TOKEN" ]]; then
  echo "No token found. Generate one at:"
  echo "  $SONAR_URL → My Account → Security → Generate Token"
  echo "  (needs Create Projects + Execute Analysis on org '$ORG')"
  read -r -s -p "Paste token: " TOKEN; echo
fi

echo ""
echo "=== Setup plan ==="
echo "  URL          : $SONAR_URL"
echo "  Organization : $ORG"
echo "  Project name : $NAME"
echo "  Project key  : $KEY"
echo ""

# --- Validate the token ------------------------------------------------------
echo "Validating token..."
valid="$(curl -s -u "$TOKEN:" "$SONAR_URL/api/authentication/validate" | tr -d ' ')"
if [[ "$valid" != *'"valid":true'* ]]; then
  echo "ERROR: token failed validation. Check the token and its permissions." >&2
  exit 1
fi
echo "  token OK"

# --- Create the project (idempotent) -----------------------------------------
echo "Creating project '$KEY' (skips if it already exists)..."
create_resp="$(curl -s -u "$TOKEN:" -X POST \
  "$SONAR_URL/api/projects/create" \
  --data-urlencode "organization=$ORG" \
  --data-urlencode "project=$KEY" \
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

# --- Write sonar-project.properties (the single source of truth) -------------
echo "Updating sonar-project.properties..."
tmp="$(mktemp)"
# Update existing lines; append sonar.host.url if not already present
sed -E \
  -e "s|^sonar\.projectKey[[:space:]]*=.*|sonar.projectKey=$KEY|" \
  -e "s|^sonar\.projectName[[:space:]]*=.*|sonar.projectName=$NAME|" \
  -e "s|^sonar\.organization[[:space:]]*=.*|sonar.organization=$ORG|" \
  -e "s|^sonar\.host\.url[[:space:]]*=.*|sonar.host.url=$SONAR_URL|" \
  "$PROPS" > "$tmp"
# Add sonar.host.url if it wasn't already in the file
if ! grep -q "^sonar\.host\.url" "$tmp"; then
  echo "sonar.host.url=$SONAR_URL" >> "$tmp"
fi
mv "$tmp" "$PROPS"
echo "  done."

# --- Tell the SE what to export ----------------------------------------------
cat <<EOF

=== Add these to ~/.zshrc (or ~/.bashrc), then restart your shell ===

export SONAR_TOKEN=$TOKEN             # sonar CLI auth
export SONARQUBE_CLOUD_TOKEN=$TOKEN   # demo-reset.sh
export SONARCLOUD_DEMOS_TOKEN=$TOKEN  # MCP server
export SONARQUBE_URL=$SONAR_URL       # MCP server + hooks (omit if using sonarcloud.io default)
export SONARQUBE_ORG=$ORG             # MCP server + hooks
export SONARQUBE_PROJECT_KEY=$KEY     # MCP server + hooks

EOF

# --- Optional first scan -----------------------------------------------------
if [[ "$RUN_SCAN" == "ask" ]]; then
  read -r -p "Run a first scan now to populate the project? (y/N) " a
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

cat <<'EOF'

=== Next ===
1. Export the vars above and restart your shell.
2. Open a fresh Claude Code session in this repo.
3. The SessionStart hook should print issue counts + "MCP: ✓ connected".
   If MCP shows ✗, run /mcp inside Claude Code to diagnose.
EOF
