#!/bin/bash
# setup.sh — one-time onboarding for an SE adopting this demo repo.
#
# Does three things in order:
#   1. Creates a private GitHub repo under your account, pushes all demo branches + tag
#   2. Creates your SonarCloud project, bound to that GitHub repo (key = <gh-user>_<repo-slug>)
#   3. Opens the demo/bad-state PR and creates your live-push branch (via demo-reset.sh)
#
# Usage:
#   bash scripts/setup.sh [--name "<Project Name>"] [--repo <repo-slug>] [--url <sonar-host>]
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

# --- Error trap: show which line failed --------------------------------------
trap 'echo "" >&2; echo "ERROR: setup.sh failed at line $LINENO. Command: $BASH_COMMAND" >&2' ERR

step() { echo ""; echo "── $* ──────────────────────────────────────"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
info() { echo "  $*"; }

echo "╔══════════════════════════════════════════════════════╗"
echo "║          SonarQube Demo Repo — SE Setup              ║"
echo "╚══════════════════════════════════════════════════════╝"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
PROPS="$REPO_ROOT/sonar-project.properties"

SONAR_URL="$(bash "$REPO_ROOT/scripts/lib/resolve-project.sh" url)"
NAME=""
REPO_SLUG=""
TOKEN="${SONAR_TOKEN:-}"
TOKEN_SOURCE="env"
RUN_SCAN="ask"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)    NAME="$2"; shift 2 ;;
    --repo)    REPO_SLUG="$2"; shift 2 ;;
    --url)     SONAR_URL="$2"; shift 2 ;;
    --token)   TOKEN="$2"; TOKEN_SOURCE="flag"; shift 2 ;;
    --scan)    RUN_SCAN="yes"; shift ;;
    --no-scan) RUN_SCAN="no"; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# --- Resolve GitHub identity -------------------------------------------------
step "GitHub identity"
GH_USER="$(GITHUB_TOKEN="" gh api /user --jq '.login')"
if [[ -z "$GH_USER" ]]; then
  echo "ERROR: could not resolve GitHub user. Run: gh auth login" >&2
  exit 1
fi
ok "GitHub user: $GH_USER"

# --- Derive names ------------------------------------------------------------
if [[ -z "$NAME" ]]; then
  read -r -p "  Project name [Customer Health Scorecard]: " NAME
  NAME="${NAME:-Customer Health Scorecard}"
fi
if [[ -z "$REPO_SLUG" ]]; then
  REPO_SLUG="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"
fi

SONAR_ORG=""  # resolved after token validation
SONAR_KEY=""  # derived from org + repo slug
GH_REPO="${GH_USER}/${REPO_SLUG}"

info "GitHub repo    : https://github.com/$GH_REPO"
info "Sonar URL      : $SONAR_URL"
info "SonarCloud org : (detected from token after validation)"

# --- SonarCloud token --------------------------------------------------------
if [[ -n "$TOKEN" && "$TOKEN_SOURCE" == "env" ]]; then
  info "Token: found in \$SONAR_TOKEN (press Enter to use it, or paste a new one to override)"
  read -r -s -p "  Token [current]: " NEW_TOKEN; echo
  [[ -n "$NEW_TOKEN" ]] && TOKEN="$NEW_TOKEN" && TOKEN_SOURCE="prompt"
elif [[ -z "$TOKEN" ]]; then
  info "Token: not set. Generate one at your SonarQube instance:"
  info "  My Account → Security → Generate Token"
  info "  (needs Create Projects + Execute Analysis)"
  read -r -s -p "  Paste token: " TOKEN; echo
  TOKEN_SOURCE="prompt"
fi
# --token flag case: already set, no prompt needed
if [[ -z "$TOKEN" ]]; then
  echo "ERROR: no token provided." >&2
  exit 1
fi
ok "Token source: $TOKEN_SOURCE"

# --- Auto-detect which SonarQube host the token works against ----------------
# Only probe if --url was not explicitly passed (i.e. still the resolver default)
RESOLVER_DEFAULT="$(bash "$REPO_ROOT/scripts/lib/resolve-project.sh" url)"
if [[ "$SONAR_URL" == "$RESOLVER_DEFAULT" ]]; then
  step "Detecting SonarQube host"
  KNOWN_URLS=("https://sonarcloud.io" "https://sonarqube.us" "https://sc-staging.io")
  VALID_URLS=()
  for url in "${KNOWN_URLS[@]}"; do
    info "Checking $url ..."
    resp="$(curl -s --max-time 5 -u "$TOKEN:" "$url/api/authentication/validate" 2>/dev/null || true)"
    if echo "$resp" | grep -q '"valid":true'; then
      ok "$url — token valid"
      VALID_URLS+=("$url")
    else
      info "  $url — not valid (skipping)"
    fi
  done

  if [[ ${#VALID_URLS[@]} -eq 0 ]]; then
    echo "ERROR: token did not validate against any known SonarQube host." >&2
    echo "       Try passing --url <host> explicitly, or check your token." >&2
    exit 1
  elif [[ ${#VALID_URLS[@]} -eq 1 ]]; then
    SONAR_URL="${VALID_URLS[0]}"
    ok "Using: $SONAR_URL"
  else
    echo ""
    echo "  Token is valid on multiple hosts:"
    for i in "${!VALID_URLS[@]}"; do
      echo "    $((i+1))) ${VALID_URLS[$i]}"
    done
    read -r -p "  Which one should this repo target? [1]: " URL_CHOICE
    URL_CHOICE="${URL_CHOICE:-1}"
    if [[ "$URL_CHOICE" -ge 1 && "$URL_CHOICE" -le "${#VALID_URLS[@]}" ]]; then
      SONAR_URL="${VALID_URLS[$((URL_CHOICE-1))]}"
      ok "Selected: $SONAR_URL"
    else
      echo "ERROR: invalid selection '$URL_CHOICE'" >&2; exit 1
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
step "1/3  GitHub repo"

if GITHUB_TOKEN="" gh repo view "$GH_REPO" --json name --jq '.name' &>/dev/null; then
  ok "Repo $GH_REPO already exists — skipping creation."
else
  info "Creating private repo $GH_REPO..."
  GITHUB_TOKEN="" gh repo create "$GH_REPO" \
    --private \
    --description "SonarQube + Claude Code SE demo — $NAME"
  ok "Repo created: https://github.com/$GH_REPO"
fi

info "Re-pointing origin → https://github.com/$GH_REPO.git"
git remote set-url origin "https://github.com/$GH_REPO.git"
ok "origin updated."

info "Pushing branches..."
for branch in main demo/bad-state demo/fixed-state; do
  if git push origin "$branch" 2>&1 | sed 's/^/    /'; then
    ok "Pushed $branch"
  else
    warn "Could not push $branch — continuing."
  fi
done

info "Pushing demo/live-push-base tag..."
if git push origin refs/tags/demo/live-push-base 2>&1 | sed 's/^/    /'; then
  ok "Pushed tag demo/live-push-base"
else
  warn "Could not push tag (may already exist on remote)."
fi

# ─────────────────────────────────────────────────────────────────────────────
step "2/3  SonarCloud project"

info "Looking up your SonarCloud organizations..."
orgs_resp="$(curl -s -u "$TOKEN:" "$SONAR_URL/api/organizations/search?member=true&ps=50")"
mapfile -t ORG_KEYS < <(echo "$orgs_resp" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for o in data.get('organizations', []):
    print(o['key'])
" 2>/dev/null)
mapfile -t ORG_NAMES < <(echo "$orgs_resp" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for o in data.get('organizations', []):
    print(o.get('name', o['key']))
" 2>/dev/null)

if [[ ${#ORG_KEYS[@]} -eq 0 ]]; then
  warn "Could not detect orgs from token. Using GitHub username as org: $GH_USER"
  SONAR_ORG="$GH_USER"
elif [[ ${#ORG_KEYS[@]} -eq 1 ]]; then
  SONAR_ORG="${ORG_KEYS[0]}"
  ok "Found 1 org: ${ORG_NAMES[0]} (${ORG_KEYS[0]}) — using it."
else
  echo ""
  echo "  Your token has access to ${#ORG_KEYS[@]} SonarCloud organizations:"
  for i in "${!ORG_KEYS[@]}"; do
    echo "    $((i+1))) ${ORG_NAMES[$i]} — ${ORG_KEYS[$i]}"
  done
  echo ""
  read -r -p "  Which org should the project be created in? [1]: " ORG_CHOICE
  ORG_CHOICE="${ORG_CHOICE:-1}"
  if [[ "$ORG_CHOICE" -ge 1 && "$ORG_CHOICE" -le "${#ORG_KEYS[@]}" ]]; then
    SONAR_ORG="${ORG_KEYS[$((ORG_CHOICE-1))]}"
    ok "Selected: ${ORG_NAMES[$((ORG_CHOICE-1))]} (${SONAR_ORG})"
  else
    echo "ERROR: invalid selection '$ORG_CHOICE'" >&2; exit 1
  fi
fi

# Re-derive key now that we have the confirmed org
SONAR_KEY="${SONAR_ORG}_${REPO_SLUG}"
info "Project key: $SONAR_KEY"

info "Creating project '$SONAR_KEY' under org '$SONAR_ORG'..."
create_resp="$(curl -s -u "$TOKEN:" -X POST \
  "$SONAR_URL/api/projects/create" \
  --data-urlencode "organization=$SONAR_ORG" \
  --data-urlencode "project=$SONAR_KEY" \
  --data-urlencode "name=$NAME")"

if echo "$create_resp" | grep -q '"project"'; then
  ok "Project created: $SONAR_KEY"
elif echo "$create_resp" | grep -qi "key already exists"; then
  ok "Project already exists — reusing."
else
  warn "Unexpected response from project create:"
  info "  $create_resp"
  info "Continuing — verify the project exists in SonarCloud."
fi

info "Updating sonar-project.properties..."
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
ok "sonar-project.properties updated."

# ─────────────────────────────────────────────────────────────────────────────
step "3/3  Demo PRs + live-push branch"

info "Running demo-reset.sh --se $GH_USER..."
export SONAR_TOKEN="$TOKEN"
bash "$REPO_ROOT/scripts/demo-reset.sh" --se "$GH_USER"

# ─────────────────────────────────────────────────────────────────────────────
step "Optional: first SonarCloud scan"

if [[ "$RUN_SCAN" == "ask" ]]; then
  read -r -p "  Run a first scan now to populate the project? (y/N) " a
  [[ "$a" =~ ^[Yy]$ ]] && RUN_SCAN="yes" || RUN_SCAN="no"
fi
if [[ "$RUN_SCAN" == "yes" ]]; then
  if command -v sonar-scanner >/dev/null 2>&1; then
    info "Running sonar-scanner..."
    sonar-scanner -Dsonar.token="$TOKEN"
  else
    warn "sonar-scanner not on PATH — skipping."
    info "Install it, then run: sonar-scanner -Dsonar.token=\$SONAR_TOKEN"
  fi
else
  info "Skipped. Run manually when ready: sonar-scanner -Dsonar.token=\$SONAR_TOKEN"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Done — env vars"

ENV_LINES=()
ENV_LINES+=("export SONAR_TOKEN=$TOKEN")
ENV_LINES+=("export SONARQUBE_ORG=$SONAR_ORG")
ENV_LINES+=("export SONARQUBE_PROJECT_KEY=$SONAR_KEY")
[[ "$SONAR_URL" != "https://sonarcloud.io" ]] && ENV_LINES+=("export SONARQUBE_URL=$SONAR_URL")

echo ""
for line in "${ENV_LINES[@]}"; do echo "  $line"; done
echo ""

# Offer to write directly to ~/.zshrc / ~/.bashrc
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then SHELL_RC="$HOME/.bashrc"; fi

if [[ -n "$SHELL_RC" ]]; then
  read -r -p "  Write these to $SHELL_RC now? (Y/n) " WRITE_RC
  WRITE_RC="${WRITE_RC:-Y}"
  if [[ "$WRITE_RC" =~ ^[Yy]$ ]]; then
    echo "" >> "$SHELL_RC"
    echo "# SonarQube demo — added by scripts/setup.sh" >> "$SHELL_RC"
    for line in "${ENV_LINES[@]}"; do echo "$line" >> "$SHELL_RC"; done
    ok "Written to $SHELL_RC"
    info "Run: source $SHELL_RC"
  else
    info "Skipped. Add the lines above to $SHELL_RC manually."
  fi
else
  info "Add the lines above to your shell rc file manually."
fi

echo ""
echo "Next: source $SHELL_RC (or restart your shell), then open a fresh"
echo "Claude Code session in this repo. The SessionStart hook should show"
echo "issue counts + 'MCP: ✓ connected'."
