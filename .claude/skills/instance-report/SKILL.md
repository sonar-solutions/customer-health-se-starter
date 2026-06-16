---
name: instance-report
description: >
  Instance-wide admin report across all projects in a SonarQube org or server.
  Triggered by: /instance-report, "show me the full instance report", "admin report",
  "how is our instance doing", "give me an org-level report", "instance health".
  Different from /sonar-audit: this covers ALL projects as an admin view, not a single
  project as a developer. Designed for SonarQube admins and engineering leaders.
tools:
  - Bash
  - mcp__sonarqube__search_security_hotspots
  - mcp__sonarqube__search_dependency_risks
  - mcp__sonarqube__list_quality_gates
---

# /instance-report — Instance-Wide Admin Report

Produces an executive-ready health report across all projects in a SonarQube organization
or server instance. Uses the `sonar api` CLI for enumeration and bulk data gathering, and
MCP tools for security and SCA data.

Designed for SonarQube admins and engineering leaders who need a full picture without
clicking through individual projects.

## Trigger

`/instance-report [org-key]`

- If `org-key` is provided, use it directly.
- If omitted, read it from `~/.sonar/sonarqube-cli/state.json` (`.orgKey` field).
- For SonarQube Server (non-Cloud), omit `organization=` params from all API calls.

## Steps

### 1. Resolve org key and instance type

```bash
cat ~/.sonar/sonarqube-cli/state.json
```

Extract `orgKey` and `serverUrl`. If `serverUrl` contains `sonarcloud.io`, this is Cloud
and all API calls need `?organization=<orgKey>`. Otherwise it's Server — omit the org param.

Set a shell variable `ORG` for use in subsequent calls.

### 2. Instance footprint (single call with facets)

```bash
sonar api get "/api/components/search_projects?organization=$ORG&ps=1&facets=alert_status,languages"
```

From the response extract:
- `paging.total` → total analyzed projects
- `facets[alert_status]` → counts for OK / ERROR / WARN
- `facets[languages]` → top languages by project count

Also get provisioned-but-never-scanned count:
```bash
sonar api get "/api/projects/search?organization=$ORG&ps=1&onProvisionedOnly=true"
```
→ `paging.total` = never-scanned projects

And stale projects (not scanned in 90+ days — compute date as 90 days before today):
```bash
sonar api get "/api/projects/search?organization=$ORG&ps=1&analyzedBefore=<90-days-ago>"
```
→ `paging.total` = stale projects

### 3. Enumerate all project keys

Page through all projects to collect their keys and `lastAnalysisDate`:

```bash
sonar api get "/api/projects/search?organization=$ORG&ps=500&p=1"
# repeat with p=2, p=3 ... until paging.pageIndex * pageSize >= paging.total
```

Build a list of all project keys for use in bulk measure fetching. Also collect
`lastAnalysisDate` for each project to identify stale and never-scanned projects.

### 4. Bulk metrics collection

Split the project key list into batches of 50. For each batch, call:

```bash
sonar api get "/api/measures/search?projectKeys=<key1,key2,...>&metricKeys=ncloc,bugs,vulnerabilities,code_smells,security_hotspots,coverage,reliability_rating,security_rating,sqale_index"
```

Aggregate across all projects:
- **Total LOC**: sum all `ncloc` values
- **Total bugs**: sum `bugs`
- **Total vulnerabilities**: sum `vulnerabilities`
- **Total code smells**: sum `code_smells`
- **Total hotspots**: sum `security_hotspots`
- **Total tech debt**: sum `sqale_index` (minutes) → convert to person-days (÷ 480)
- **E-rated security**: projects where `security_rating = 5`
- **E-rated reliability**: projects where `reliability_rating = 5`
- **Coverage buckets**: count projects with `coverage = 0`, `< 50`, `50–80`, `> 80`
- **Issue density per project**: `(bugs + vulnerabilities) / (ncloc / 1000)` — sort descending for top 10

Skip projects with `ncloc = 0` or missing ncloc from density calculations.

### 5. Quality gate audit

```bash
sonar api get "/api/qualitygates/list?organization=$ORG"
```

For each gate, note:
- Name, whether it's the default, whether it's built-in
- Condition count — flag gates with 0 conditions as ⚠ EMPTY
- Whether all conditions are on `new_*` metrics (good) vs overall metrics (flag as ⚠)
- Whether any conditions use deprecated metrics

For each custom gate (non-built-in), get its project assignments:
```bash
sonar api get "/api/qualitygates/search?organization=$ORG&gateId=<id>&ps=500"
```
→ note project count per gate

Flag gates that have 0 projects assigned as potentially unused.

### 6. Quality profile audit

```bash
sonar api get "/api/qualityprofiles/search?organization=$ORG"
```

Group by language. For each language note the number of custom profiles (non-built-in).
Flag custom profiles with `projectCount = 0` as unused.

Count total languages with active custom profiles vs. languages using only Sonar way defaults.

### 7. Instance-wide issue counts

```bash
sonar api get "/api/issues/search?organization=$ORG&statuses=OPEN&types=VULNERABILITY&ps=1&facets=severities"
sonar api get "/api/issues/search?organization=$ORG&statuses=OPEN&types=BUG&ps=1&facets=severities"
```

Extract totals and severity breakdowns from `paging.total` and facets.

### 8. SCA dependency risks

Call `search_dependency_risks` (MCP). Count OPEN risks by severity (HIGH, MEDIUM, LOW).
Note how many distinct projects are affected.

### 9. Security hotspots to review

Call `search_security_hotspots` with `status: ["TO_REVIEW"]` (MCP).
Count total and note the top 3 most common security categories.

### 10. Render report

Use all collected data to produce the report below. All sections are always shown — omit
nothing even if counts are zero.

Convert `sqale_index` (minutes) to person-days: divide by 480 (8-hour day × 60 minutes).
Round tech debt to nearest whole day.

For ratings, map values: 1=A, 2=B, 3=C, 4=D, 5=E.

Sort the top-10 issue density table by density descending. If fewer than 10 projects have
analyzable code, show as many as are available.

---

## Report Format

```
INSTANCE REPORT — <org-key or server URL>
==========================================
Generated: <date>  |  Instance: SonarQube Cloud / Server

FOOTPRINT
  Total projects:       <N>
  Analyzed projects:    <N>  (<N> passing QG · <N> failing · <N> warning)
  Never scanned:        <N>  (created but no analysis)
  Stale (>90 days):     <N>
  Total LOC:            <N> lines across all projects

  Languages: <lang1> (<N>)  <lang2> (<N>)  <lang3> (<N>)  ...

QUALITY GATE HEALTH
  Pass rate: <N>% (<N>/<N> analyzed projects passing)

  Gates defined: <N> total  (<N> custom · <N> built-in · 1 default)
  <gate-name> [DEFAULT]  — <N> conditions  — <N> projects
  <gate-name>            — <N> conditions  — <N> projects
  ⚠ <gate-name>          — 0 conditions (no enforcement)
  ...

CODE QUALITY ROLLUP
  Bugs:              <N>  |  Vulnerabilities: <N>  |  Code Smells: <N>
  Hotspots to review: <N>
  Technical debt:    <N> person-days

  Coverage distribution:
    No coverage (0%):   <N> projects
    Low  (<50%):        <N> projects
    Fair (50–80%):      <N> projects
    Good (>80%):        <N> projects

RISK: E-RATED PROJECTS
  Security E:     <project-name>, <project-name>, ...
  Reliability E:  <project-name>, <project-name>, ...
  (If none, show "No E-rated projects ✓")

TOP 10 BY ISSUE DENSITY  (bugs + vulns per KLOC)
   1. <project-name>        <N.N> issues/KLOC  (<N> bugs, <N> vulns, <N> KLOC)
   2. ...
  10. ...

QUALITY PROFILES
  <N> custom profiles defined across <N> languages
  ⚠ Unused custom profiles (<N>): <profile-name> (<lang>), ...
  (If none unused, show "All custom profiles in use ✓")

SCA DEPENDENCY RISKS
  <N> open risks across <N> projects
  HIGH: <N>  |  MEDIUM: <N>  |  LOW: <N>

SECURITY HOTSPOTS
  <N> hotspots requiring review
  Top categories: <category> (<N>), <category> (<N>), <category> (<N>)

RECOMMENDED ACTIONS
  1. <most impactful action based on findings>
  2. <second action>
  3. <third action>
```

Recommendations should be specific to what the data shows — e.g. if 8 projects have
E-rated security, say "Run /security-posture on <project-name> — highest vulnerability
density". If there are empty quality gates, name them. If many projects are never scanned,
recommend a scan adoption initiative. Do not produce generic advice.
