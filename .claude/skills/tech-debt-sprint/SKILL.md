---
name: tech-debt-sprint
description: >
  Tech debt analysis with two-wave agent orchestration — metrics and hotspots in parallel,
  then blast radius analysis. Produces a prioritized remediation plan.
  Triggered by: /tech-debt-sprint, "analyze tech debt", "where's the worst code",
  "what should we fix first", "prioritize the backlog".
tools:
  - Agent
---

# /tech-debt-sprint — Tech Debt Analysis

Uses a two-wave agent orchestration pattern to produce a prioritized tech debt report ranked by blast radius.

## Trigger

`/tech-debt-sprint`

## Architecture

```
/tech-debt-sprint (orchestrator)
    │
    ├── WAVE 1 (parallel)
    │   ├── health-analyzer agent      ── health dashboard + coverage + quality gate
    │   └── debt-hotspot-finder agent  ── top 5 debt files
    │
    ├── WAVE 2 (sequential, uses Wave 1 results)
    │   └── blast-radius-tracer agent  ── dependency impact of top files
    │
    └── Synthesize into prioritized remediation plan
```

## Steps

### Step 1 — Wave 1: Gather metrics and hotspots (parallel)

Launch two agents **in parallel** using a single message with multiple Agent tool calls:

1. **health-analyzer agent** — gather coverage, complexity, duplication, quality gate status
2. **debt-hotspot-finder agent** — find the top 5 files by bug/code-smell density

### Step 2 — Wave 2: Trace blast radius (sequential)

Once Wave 1 completes, launch the **blast-radius-tracer agent** with the top files identified by the debt-hotspot-finder. Include the file paths and method FQNs from the hotspot findings.

### Step 3 — Synthesize

Combine all three agent reports into a single prioritized remediation plan:

```
TECH DEBT SPRINT REPORT
========================

PROJECT HEALTH (from health-analyzer)
  Quality Gate: [PASSED / FAILED]
  Coverage: <N>% | Duplication: <N>% | Complexity: <N>
  Bugs: <N> | Code Smells: <N>

DEBT HOTSPOTS (from debt-hotspot-finder)
  #1 <file> — <N> issues (<dominant category>)
  #2 <file> — <N> issues (<dominant category>)
  #3 <file> — <N> issues (<dominant category>)
  #4 <file> — <N> issues (<dominant category>)
  #5 <file> — <N> issues (<dominant category>)

BLAST RADIUS (from blast-radius-tracer)
  Most central: <file/method> — <N> dependents
  Most isolated: <file/method> — <N> dependents

PRIORITIZED REMEDIATION PLAN
  Fix in this order (low risk first, high impact last):
  1. <file> — <N> issues, <N> dependents — safest to start
  2. <file> — <N> issues, <N> dependents
  3. <file> — <N> issues, <N> dependents — highest risk, fix last

  Estimated approach:
  - Use /sonar-fix for individual issues
  - Use /sonar-blitz to batch-fix a file
```

## Error Handling

- If Wave 1 health-analyzer fails, proceed with hotspot data only
- If Wave 1 debt-hotspot-finder fails, skip Wave 2 (no targets for blast radius)
- If Wave 2 blast-radius-tracer fails, report hotspots without dependency ranking
- Always produce a report with whatever data is available
