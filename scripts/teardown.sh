#!/bin/bash
# teardown.sh — undo setup.sh so you can run it again cleanly.
#
# Reverses the three things setup.sh does:
#   1. Deletes the GitHub repo created for this SE
#   2. Deletes the SonarCloud project
#   3. Resets sonar-project.properties and git origin to template defaults
#
# Reads the current sonar-project.properties to know what to tear down —
# run from the repo where setup.sh was run.
#
# Usage:
#   bash scripts/teardown.sh [--keep-gh] [--keep-sonar] [--keep-rc]
#
#   --keep-gh     skip GitHub repo deletion
#   --keep-sonar  skip SonarCloud project deletion
#   --keep-rc     skip removing env vars from ~/.zshrc / ~/.bashrc

set -euo pipefail
trap 'echo "" >&2; echo "ERROR: teardown.sh failed at line $LINENO. Command: $BASH_COMMAND" >&2' ERR

step() { echo ""; echo "── $* ──────────────────────────────────────"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
info() { echo "  $*"; }

KEEP_GH=false
KEEP_SONAR=false
KEEP_RC=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-gh)    KEEP_GH=true; shift ;;
    --keep-sonar) KEEP_SONAR=true; shift ;;
    --keep-rc)    KEEP_RC=true; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
PROPS="$REPO_ROOT/sonar-project.properties"

# --- Read current config from properties -------------------------------------
prop() {
  { grep -E "^$1[[:space:]]*=" "$PROPS" 2>/dev/null || true; } | head -1 \
    | sed -E "s/^$1[[:space:]]*=[[:space:]]*//" | sed -E 's/[[:space:]]+$//'
}

SONAR_KEY="$(prop 'sonar\.projectKey')"
SONAR_ORG="$(prop 'sonar\.organization')"
SONAR_URL="$(prop 'sonar\.host\.url')"
SONAR_URL="${SONAR_URL:-https://sonarcloud.io}"

# Derive GitHub repo from project key (<org>_<slug> → <org>/<slug>)
if [[ -n "$SONAR_KEY" && "$SONAR_KEY" != "sonar-solutions_Health-Dashboard" ]]; then
  GH_REPO="$(echo "$SONAR_KEY" | cut -d_ -f1)/$(echo "$SONAR_KEY" | cut -d_ -f2-)"
else
  GH_REPO=""
fi

echo "╔══════════════════════════════════════════════════════╗"
echo "║          SonarQube Demo Repo — Teardown              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
info "Will tear down:"
info "  GitHub repo    : $GH_REPO"
info "  SonarCloud key : $SONAR_KEY  ($SONAR_URL)"
info "  Reset origin   → https://github.com/sonar-solutions/Health-Dashboard.git"
echo ""
read -r -p "Continue? (y/N) " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ─────────────────────────────────────────────────────────────────────────────
step "1/3  GitHub repo"

if [[ "$KEEP_GH" == true ]]; then
  info "Skipped (--keep-gh)."
elif [[ -z "$GH_REPO" ]]; then
  warn "Could not derive GitHub repo from project key — skipping. Delete manually if needed."
else
  info "Deleting https://github.com/$GH_REPO ..."
  delete_out="$(GITHUB_TOKEN="" gh repo delete "$GH_REPO" --yes 2>&1)" && ok "Deleted $GH_REPO." || {
    if echo "$delete_out" | grep -q "delete_repo"; then
      warn "Missing 'delete_repo' scope. Grant it once with:"
      info "  gh auth refresh -h github.com -s delete_repo"
      info "Then re-run teardown.sh, or delete the repo manually at:"
      info "  https://github.com/$GH_REPO/settings"
    else
      warn "Could not delete $GH_REPO: $delete_out"
    fi
  }
fi

# ─────────────────────────────────────────────────────────────────────────────
step "2/3  SonarCloud project"

if [[ "$KEEP_SONAR" == true ]]; then
  info "Skipped (--keep-sonar)."
elif [[ -z "$SONAR_KEY" || "$SONAR_KEY" == "sonar-solutions_Health-Dashboard" ]]; then
  warn "Project key looks like the shared template project — skipping deletion for safety."
else
  TOKEN="${SONAR_TOKEN:-}"
  if [[ -z "$TOKEN" ]]; then
    read -r -s -p "  SONAR_TOKEN not set — paste token to delete project: " TOKEN; echo
  fi
  if [[ -n "$TOKEN" ]]; then
    info "Deleting SonarCloud project $SONAR_KEY ..."
    del_resp="$(curl -s -u "$TOKEN:" -X POST \
      "$SONAR_URL/api/projects/delete" \
      --data-urlencode "project=$SONAR_KEY" || true)"
    if [[ -z "$del_resp" ]]; then
      ok "Deleted $SONAR_KEY."
    else
      warn "Unexpected response: $del_resp"
      info "Verify manually at $SONAR_URL."
    fi
  else
    warn "No token — skipping SonarCloud project deletion."
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
step "3/3  Reset local config"

info "Resetting sonar-project.properties to template defaults..."
cat > "$PROPS" <<'PROPS'
sonar.projectKey=sonar-solutions_Health-Dashboard
sonar.projectName=Health Dashboard
sonar.organization=sonar-solutions

sonar.sources=backend/app,frontend/src
sonar.tests=backend/tests,frontend/tests
sonar.exclusions=**/node_modules/**,**/__pycache__/**

sonar.python.version=3
sonar.python.coverage.reportPaths=backend/coverage.xml

sonar.javascript.lcov.reportPaths=frontend/coverage/lcov.info
sonar.typescript.tsconfigPath=frontend/tsconfig.json
PROPS
ok "sonar-project.properties reset."

info "Resetting git origin → sonar-solutions/Health-Dashboard..."
git remote set-url origin "https://github.com/sonar-solutions/Health-Dashboard.git"
ok "origin reset."

# Commit the reset so the working tree is clean for the next setup.sh run
if ! git diff --quiet "$PROPS" 2>/dev/null; then
  git add "$PROPS"
  git commit -m "chore(teardown): reset sonar-project.properties to template defaults" --no-verify
  ok "Committed reset."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Optional: scrub env vars from shell rc
if [[ "$KEEP_RC" == false ]]; then
  SHELL_RC=""
  [[ -f "$HOME/.zshrc" ]]  && SHELL_RC="$HOME/.zshrc"
  [[ -f "$HOME/.bashrc" ]] && SHELL_RC="$HOME/.bashrc"

  if [[ -n "$SHELL_RC" ]] && grep -q "# SonarQube demo — added by scripts/setup.sh" "$SHELL_RC" 2>/dev/null; then
    info "Removing SonarQube demo env vars from $SHELL_RC ..."
    # Remove the comment line and the export lines that follow it
    python3 - "$SHELL_RC" <<'EOF'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
out, skip = [], False
for line in lines:
    if line.strip() == "# SonarQube demo — added by scripts/setup.sh":
        skip = True
    if skip and not line.startswith("export SONAR") and not line.startswith("export SONARQUBE") and not line.startswith("# SonarQube"):
        skip = False
    if not skip:
        out.append(line)
with open(path, "w") as f:
    f.writelines(out)
EOF
    ok "Removed from $SHELL_RC."
    info "Run: source $SHELL_RC"
  else
    info "No SonarQube demo vars found in shell rc — nothing to remove."
  fi
fi

echo ""
echo "Teardown complete. Run setup.sh again to start fresh:"
echo "  bash scripts/setup.sh"
