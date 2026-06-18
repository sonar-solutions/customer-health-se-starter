#!/bin/bash
# setup.sh — one-time onboarding for an SE adopting this demo repo.
#
# Does three things in order:
#   1. Creates a private GitHub repo, pushes all demo branches + tag, sets SONAR_TOKEN secret
#   2. Creates your SonarCloud project (key = <gh-user>_<repo-slug>)
#   3. Opens the demo/bad-state PR and creates your live-push branch (via demo-reset.sh)
#
# Usage:
#   bash scripts/setup.sh [--name "<Project Name>"] [--url <sonar-host>]
#
# Defaults:
#   --name  "Customer Health Scorecard"
#   --url   auto-detected from your token (checks sonarcloud.io, sonarqube.us, sc-staging.io)
#
# GitHub user and SonarCloud org are both read from gh auth + token.
# SonarCloud project key = <sonar-org>_<repo-slug>
#
# Requires:
#   - SONAR_TOKEN: SonarCloud token with Create Projects + Execute Analysis
#   - gh auth login already done

set -euo pipefail
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

NAME=""
TOKEN="${SONAR_TOKEN:-}"
SONAR_URL=""  # resolved during host detection unless --url is passed

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)   NAME="$2"; shift 2 ;;
    --url)    SONAR_URL="$2"; shift 2 ;;
    --token)  TOKEN="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# --- GitHub identity ---------------------------------------------------------
step "GitHub identity"
GH_USER="$(GITHUB_TOKEN="" gh api /user --jq '.login')"
[[ -z "$GH_USER" ]] && { echo "ERROR: run gh auth login first" >&2; exit 1; }
ok "GitHub user: $GH_USER"

if [[ -z "$NAME" ]]; then
  read -r -p "  Project name [Customer Health Scorecard]: " NAME
  NAME="${NAME:-Customer Health Scorecard}"
fi

REPO_SLUG="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"
GH_REPO="${GH_USER}/${REPO_SLUG}"
info "GitHub repo : https://github.com/$GH_REPO"

# --- Token -------------------------------------------------------------------
if [[ -z "$TOKEN" ]]; then
  info "SONAR_TOKEN not set. Generate one: My Account → Security → Generate Token"
  info "(needs Create Projects + Execute Analysis)"
  read -r -s -p "  Paste token: " TOKEN; echo
fi
[[ -z "$TOKEN" ]] && { echo "ERROR: no token provided." >&2; exit 1; }

# --- Host detection ----------------------------------------------------------
# Skip if --url was passed explicitly.
if [[ -z "$SONAR_URL" ]]; then
  step "Detecting SonarQube host"

  # Add a row here for each new host/token-var pair.
  declare -a KNOWN_URLS=("https://sonarcloud.io" "https://sonarqube.us" "https://sc-staging.io")
  declare -a KNOWN_VARS=("SONAR_TOKEN"            "SONAR_TOKEN"          "SQC_STAGING_TOKEN")

  VALID_URLS=()
  VALID_TOKENS=()
  for i in "${!KNOWN_URLS[@]}"; do
    url="${KNOWN_URLS[$i]}"
    var="${KNOWN_VARS[$i]}"
    t="${!var:-}"
    if [[ -z "$t" ]]; then
      info "$url — skipped (\$$var not set)"
      continue
    fi
    info "Checking $url..."
    resp="$(curl -s --max-time 5 -u "$t:" "$url/api/authentication/validate" 2>/dev/null || true)"
    if echo "$resp" | grep -q '"valid":true'; then
      ok "$url — valid"
      VALID_URLS+=("$url")
      VALID_TOKENS+=("$t")
    else
      info "  not valid (skipping)"
    fi
  done

  if [[ ${#VALID_URLS[@]} -eq 0 ]]; then
    echo "ERROR: no host validated. Check SONAR_TOKEN or pass --url." >&2; exit 1
  elif [[ ${#VALID_URLS[@]} -eq 1 ]]; then
    SONAR_URL="${VALID_URLS[0]}"
    TOKEN="${VALID_TOKENS[0]}"
    ok "Using: $SONAR_URL"
  else
    echo ""
    for i in "${!VALID_URLS[@]}"; do echo "    $((i+1))) ${VALID_URLS[$i]}"; done
    read -r -p "  Multiple hosts valid — which one? [1]: " c
    c="${c:-1}"
    SONAR_URL="${VALID_URLS[$((c-1))]}"
    TOKEN="${VALID_TOKENS[$((c-1))]}"
    ok "Selected: $SONAR_URL"
  fi
fi
ok "Token: (${TOKEN:0:4})•••• → $SONAR_URL"

# ─────────────────────────────────────────────────────────────────────────────
step "1/4  GitHub repo"

if GITHUB_TOKEN="" gh repo view "$GH_REPO" --json name --jq '.name' &>/dev/null; then
  ok "Repo already exists — skipping creation."
else
  info "Creating $GH_REPO..."
  GITHUB_TOKEN="" gh repo create "$GH_REPO" \
    --private \
    --description "SonarQube + Claude Code SE demo — $NAME"
  ok "Created: https://github.com/$GH_REPO"
fi

info "Setting SONAR_TOKEN secret..."
GITHUB_TOKEN="" gh secret set SONAR_TOKEN --body "$TOKEN" --repo "$GH_REPO"
ok "SONAR_TOKEN secret set."

info "Re-pointing origin → https://github.com/$GH_REPO.git"
git remote set-url origin "https://github.com/$GH_REPO.git"

info "Pushing branches..."
for branch in main demo/bad-state demo/fixed-state; do
  git push origin "$branch" 2>&1 | sed 's/^/    /' && ok "Pushed $branch" \
    || warn "Could not push $branch"
done

info "Pushing demo/live-push-base tag..."
git push origin refs/tags/demo/live-push-base 2>&1 | sed 's/^/    /' \
  && ok "Pushed tag" || warn "Could not push tag (may already exist)"

# ─────────────────────────────────────────────────────────────────────────────
step "2/4  SonarCloud project"

info "Looking up organizations..."
orgs_resp="$(curl -s -u "$TOKEN:" "$SONAR_URL/api/organizations/search?member=true&ps=50")"
ORG_KEYS=()
ORG_NAMES=()
while IFS='|' read -r key name; do
  [[ -z "$key" ]] && continue
  ORG_KEYS+=("$key")
  ORG_NAMES+=("$name")
done < <(echo "$orgs_resp" | python3 -c "
import json, sys
for o in json.load(sys.stdin).get('organizations', []):
    print(o['key'] + '|' + o.get('name', o['key']))
" 2>/dev/null)

if [[ ${#ORG_KEYS[@]} -eq 0 ]]; then
  warn "Could not detect orgs — using GitHub username: $GH_USER"
  SONAR_ORG="$GH_USER"
elif [[ ${#ORG_KEYS[@]} -eq 1 ]]; then
  SONAR_ORG="${ORG_KEYS[0]}"
  ok "Org: ${ORG_NAMES[0]} (${ORG_KEYS[0]})"
else
  echo ""
  for i in "${!ORG_KEYS[@]}"; do
    echo "    $((i+1))) ${ORG_NAMES[$i]} — ${ORG_KEYS[$i]}"
  done
  read -r -p "  Which org? [1]: " c
  c="${c:-1}"
  SONAR_ORG="${ORG_KEYS[$((c-1))]}"
  ok "Selected: ${ORG_NAMES[$((c-1))]} ($SONAR_ORG)"
fi

SONAR_KEY="${SONAR_ORG}_${REPO_SLUG}"
info "Project key: $SONAR_KEY"

info "Creating project..."
create_resp="$(curl -s -u "$TOKEN:" -X POST "$SONAR_URL/api/projects/create" \
  --data-urlencode "organization=$SONAR_ORG" \
  --data-urlencode "project=$SONAR_KEY" \
  --data-urlencode "name=$NAME")"

if echo "$create_resp" | grep -q '"project"'; then
  ok "Project created."
elif echo "$create_resp" | grep -qi "key already exists"; then
  ok "Project already exists — reusing."
else
  warn "Unexpected response: $create_resp"
  info "Verify the project exists in SonarCloud before continuing."
fi

info "Updating sonar-project.properties..."
tmp="$(mktemp)"
sed -E \
  -e "s|^sonar\.projectKey[[:space:]]*=.*|sonar.projectKey=$SONAR_KEY|" \
  -e "s|^sonar\.projectName[[:space:]]*=.*|sonar.projectName=$NAME|" \
  -e "s|^sonar\.organization[[:space:]]*=.*|sonar.organization=$SONAR_ORG|" \
  -e "/^sonar\.host\.url[[:space:]]*=/d" \
  "$PROPS" > "$tmp"
# sonar.host.url causes the scanner to treat the target as SonarQube Server.
# Only write it for non-sonarcloud.io targets.
[[ "$SONAR_URL" != "https://sonarcloud.io" ]] && echo "sonar.host.url=$SONAR_URL" >> "$tmp"
mv "$tmp" "$PROPS"
ok "sonar-project.properties updated."

git add "$PROPS"
git commit -m "chore(setup): configure SonarQube project for $GH_USER

Project key: $SONAR_KEY  |  Org: $SONAR_ORG  |  URL: $SONAR_URL" --no-verify
git push origin main --quiet
ok "Committed and pushed."

# ─────────────────────────────────────────────────────────────────────────────
step "3/4  Demo PRs + live-push branch"

export SONAR_TOKEN="$TOKEN"
bash "$REPO_ROOT/scripts/demo-reset.sh" --se "$GH_USER"

# ─────────────────────────────────────────────────────────────────────────────
step "4/4  Project environment"

ENV_FILE="$REPO_ROOT/.sonar-env"
{
  echo "# SonarQube demo — generated by scripts/setup.sh (gitignored)"
  echo "export SONAR_TOKEN=\"$TOKEN\""
  echo "export SONARQUBE_ORG=\"$SONAR_ORG\""
  echo "export SONARQUBE_PROJECT_KEY=\"$SONAR_KEY\""
  [[ "$SONAR_URL" != "https://sonarcloud.io" ]] && echo "export SONARQUBE_URL=\"$SONAR_URL\""
} > "$ENV_FILE"
ok "Wrote .sonar-env (project-local, gitignored)"

if command -v direnv &>/dev/null; then
  if [[ ! -f "$REPO_ROOT/.envrc" ]]; then
    echo 'source_env .sonar-env' > "$REPO_ROOT/.envrc"
    direnv allow "$REPO_ROOT"
    ok "direnv configured — env loads automatically when you cd here"
  else
    info ".envrc already exists — add 'source_env .sonar-env' manually if needed"
  fi
else
  info "direnv not found. To auto-load env on cd: brew install direnv"
  info "  then add: eval \"\$(direnv hook zsh)\" to ~/.zshrc"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Done"

echo ""
if command -v direnv &>/dev/null; then
  echo "  direnv is configured — env loads automatically when you cd to this repo."
  echo "  Open a fresh Claude Code session and the SessionStart hook will confirm:"
  echo "    MCP: ✓ connected  |  issue counts from $SONAR_KEY"
else
  echo "  Activate this project's SonarQube connection:"
  echo ""
  echo "    source .sonar-env"
  echo "    # then open a fresh Claude Code session"
  echo ""
  echo "  Or install direnv to load it automatically on cd:"
  echo "    brew install direnv"
  echo "    echo 'eval \"\$(direnv hook zsh)\"' >> ~/.zshrc"
  echo "    source ~/.zshrc && direnv allow"
fi
