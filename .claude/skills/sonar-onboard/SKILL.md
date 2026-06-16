---
name: sonar-onboard
description: >
  Developer onboarding briefing. Spawns parallel agents to gather architecture,
  quality standards, and issue landscape, then synthesizes a project orientation.
  Triggered by: /sonar-onboard, "I'm new to this project", "give me an overview",
  "onboard me", "what do I need to know about this codebase".
  Different from /sonar-audit: this focuses on HOW TO WORK HERE (architecture,
  workflow, standards), not WHAT'S BROKEN (issues, risks).
tools:
  - Agent
  - Read
---

# /sonar-onboard — Developer Onboarding Briefing

Produces a living project orientation by spawning three parallel research agents. Focuses on *how to work here* — architecture, quality standards, workflow conventions — not on what's broken (that's `/sonar-audit`).

## Trigger

`/sonar-onboard`

## Architecture

```
/sonar-onboard (orchestrator)
    │
    ├── PARALLEL RESEARCH
    │   ├── architecture-analyzer agent  ── module structure, constraints, key files
    │   ├── health-analyzer agent        ── quality standards, coverage, gate status
    │   └── debt-hotspot-finder agent    ── issue landscape, suggested first task
    │
    └── Synthesize into project onboarding briefing
```

## Steps

### Step 1 — Launch 3 research agents (parallel)

Launch all three agents **in parallel** using a single message with multiple Agent tool calls:

1. **architecture-analyzer agent** — understand module structure, constraints, and key dependencies
2. **health-analyzer agent** — gather quality gate status, coverage targets, metrics, and health dashboard
3. **debt-hotspot-finder agent** — identify issue landscape and find a good "first task" (a MINOR bug or code smell in a non-critical file)

### Step 2 — Read project workflow

While agents are running, read `CLAUDE.md` to extract the development workflow rules (mandatory checks before editing, verification requirements, key principles).

### Step 3 — Synthesize onboarding briefing

```
PROJECT ONBOARDING BRIEFING
============================
Project: <project-key>
Generated: <date>

WHAT THIS PROJECT IS
  <1-2 sentence summary from README.md or CLAUDE.md>

ARCHITECTURE (from architecture-analyzer)
  Module structure:
    <package> — <purpose>
    <package> — <purpose>

  Key files (by centrality):
    <file> — <N> dependents — <purpose>
    <file> — <N> dependents — <purpose>

  Constraints:
    <from> -> <to>: ALLOWED
    <or: "No constraints defined — see /arch-guard for recommendations">

QUALITY STANDARDS (from health-analyzer + CLAUDE.md)
  Quality Gate: [PASSED / FAILED]
  Coverage target: <N>%
  Current coverage: <N>%

  Enforced rules (from SonarQube):
    1. <rule>
    2. <rule>
    ...

  Development workflow:
    - Before editing: call get_guidelines
    - After editing: run `sonar verify --file <path>`
    - Before committing: check quality gate

CURRENT STATE (from debt-hotspot-finder)
  Open bugs: <N>
  Open code smells: <N>
  Hotspot files: <list>

YOUR FIRST TASK
  Suggested starter issue:
    <file>:<line> — <rule key> — <message>
    Severity: MINOR
    Why this one: <rationale — non-critical file, clear fix, good learning exercise>
    Fix it with: /sonar-fix <issue-key>

USEFUL COMMANDS
  /sonar-audit        — quick risk overview (what's broken)
  /sonar-fix          — fix the top issue
  /pre-push-review    — check your changes before pushing
  /security-posture   — deep security assessment
  /tech-debt-sprint   — prioritized debt analysis
```

## Error Handling

- If any agent fails, produce the briefing with available data and note the gap
- If CLAUDE.md is missing, skip the workflow section and note it
- Always produce a briefing — partial is better than nothing for a new developer
