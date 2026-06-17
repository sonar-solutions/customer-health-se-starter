#!/bin/bash
# resolve-project.sh — single source of truth for SonarQube connection config.
#
# Resolution order (env takes precedence over sonar-project.properties):
#   1. Environment variable  ($SONARQUBE_PROJECT_KEY, $SONARQUBE_ORG, $SONARQUBE_URL)
#   2. sonar-project.properties  (sonar.projectKey, sonar.organization, sonar.host.url)
#   3. Built-in default  (URL only: https://sonarcloud.io)
#
# Usage:
#   KEY=$(bash scripts/lib/resolve-project.sh key)
#   ORG=$(bash scripts/lib/resolve-project.sh org)
#   URL=$(bash scripts/lib/resolve-project.sh url)
#   eval "$(bash scripts/lib/resolve-project.sh)"   # sets SONAR_PROJECT_KEY, SONAR_ORG, SONAR_URL

root="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
props="$root/sonar-project.properties"

prop() {
  grep -E "^$1[[:space:]]*=" "$props" 2>/dev/null | head -1 \
    | sed -E "s/^$1[[:space:]]*=[[:space:]]*//" | sed -E 's/[[:space:]]+$//'
}

KEY="${SONARQUBE_PROJECT_KEY:-$(prop 'sonar\.projectKey')}"
ORG="${SONARQUBE_ORG:-$(prop 'sonar\.organization')}"
URL="${SONARQUBE_URL:-$(prop 'sonar\.host\.url')}"
URL="${URL:-https://sonarcloud.io}"

case "$1" in
  key) echo "$KEY" ;;
  org) echo "$ORG" ;;
  url) echo "$URL" ;;
  *)   printf "SONAR_PROJECT_KEY=%q\nSONAR_ORG=%q\nSONAR_URL=%q\n" "$KEY" "$ORG" "$URL" ;;
esac
