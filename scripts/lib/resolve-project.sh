#!/bin/bash
# resolve-project.sh — single source of truth for the SonarQube project key + org.
#
# Resolution order (so .mcp.json's env-based config and the hooks always agree):
#   1. $SONARQUBE_PROJECT_KEY / $SONARQUBE_ORG  (what .mcp.json uses at runtime)
#   2. sonar-project.properties                 (what session-start.py reads)
#
# Usage:
#   KEY=$(bash scripts/lib/resolve-project.sh key)
#   ORG=$(bash scripts/lib/resolve-project.sh org)
#   eval "$(bash scripts/lib/resolve-project.sh)"   # sets SONAR_PROJECT_KEY, SONAR_ORG

root="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
props="$root/sonar-project.properties"

prop() {
  grep -E "^$1[[:space:]]*=" "$props" 2>/dev/null | head -1 \
    | sed -E "s/^$1[[:space:]]*=[[:space:]]*//" | sed -E 's/[[:space:]]+$//'
}

KEY="${SONARQUBE_PROJECT_KEY:-$(prop 'sonar\.projectKey')}"
ORG="${SONARQUBE_ORG:-$(prop 'sonar\.organization')}"

case "$1" in
  key) echo "$KEY" ;;
  org) echo "$ORG" ;;
  *)   printf "SONAR_PROJECT_KEY=%q\nSONAR_ORG=%q\n" "$KEY" "$ORG" ;;
esac
