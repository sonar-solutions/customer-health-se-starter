---
name: sonar-audit
description: >
  Quick 5-minute risk overview of the current project. Shows what's broken right now.
  Triggered by: /sonar-audit, "what's the state of this project", "audit this codebase",
  "what's wrong with this code", "quick project check".
  For deep analysis, see /security-posture, /tech-debt-sprint, or /arch-guard.
tools:
  - mcp__sonarqube__get_guidelines
  - mcp__sonarqube__get_project_quality_gate_status
  - mcp__sonarqube__get_component_measures
  - mcp__sonarqube__search_sonar_issues_in_projects
  - mcp__sonarqube__search_security_hotspots
  - mcp__sonarqube__get_current_architecture
  - Read
---

# /sonar-audit — Quick Risk Overview

A fast, flat (no sub-agents) project health check for **returning developers** checking current state. Focuses on **what's broken right now** — issues, vulnerabilities, quality gate status, and key metrics.

Different from `/sonar-onboard`: this skill answers "what's wrong?" while `/sonar-onboard` answers "how do I work here?" (architecture, workflow, standards — for developers new to the repo).

For deeper analysis, use:
- `/security-posture` — full security assessment with attack chain tracing
- `/tech-debt-sprint` — prioritized tech debt analysis with blast radius
- `/arch-guard` — architecture compliance check
- `/sonar-onboard` — new developer orientation (how to work here)

## Trigger

`/sonar-audit [optional focus area]`

Examples:
- `/sonar-audit` — full overview
- `/sonar-audit security` — focus on vulnerabilities and hotspots
- `/sonar-audit scoring.py` — focus on a specific file

## Steps

### 1. Quality gate and metrics
- Call `get_project_quality_gate_status` — report verdict and any failing conditions
- Call `get_component_measures` for coverage, complexity, duplication, bug/vuln/smell counts

### 2. Live project guidelines
- Call `get_guidelines` with `mode: "project_based"` to see rules derived from this project's actual issues

### 3. Issue landscape
- Call `search_sonar_issues_in_projects` with `issueStatuses: ["OPEN"]` — group by severity
- Call `search_security_hotspots` — note any requiring review

### 4. Architecture snapshot
- Call `get_current_architecture` at depth=1 for a quick module overview

### 5. Report

```
SONAR AUDIT — <project-key>
============================

QUALITY GATE: [PASSED / FAILED]
  <failing conditions if any>

METRICS
  Lines of Code: <N> | Coverage: <N>% | Duplication: <N>%
  Bugs: <N> | Vulnerabilities: <N> | Code Smells: <N>

TOP RULES IN EFFECT
  1. <rule description>
  2. <rule description>
  ...

OPEN ISSUES BY SEVERITY
  BLOCKER: <N>
  CRITICAL: <N>
  MAJOR: <N>
  MINOR: <N>

  Worst: <file>:<line> — <message>

SECURITY HOTSPOTS: <N> requiring review

ARCHITECTURE
  <2-3 line module summary>

RECOMMENDED NEXT STEPS
  1. /sonar-fix — fix the highest-severity issue
  2. /security-posture — deep security assessment
  3. /tech-debt-sprint — prioritized debt analysis
```
