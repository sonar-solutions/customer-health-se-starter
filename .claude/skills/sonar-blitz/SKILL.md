---
name: sonar-blitz
description: >
  Autonomous multi-issue fixer. Fans out parallel issue-fixer agents to remediate
  multiple issues simultaneously, one per affected file.
  Triggered by: /sonar-blitz, "fix all the issues", "clean up the project",
  "fix everything sonarqube found".
tools:
  - mcp__sonarqube__search_sonar_issues_in_projects
  - Agent
  - Bash
---

# /sonar-blitz — Autonomous Multi-Issue Fixer

Queries all open issues, groups by file, and spawns parallel `issue-fixer` agents — one per affected file. Each agent runs the full AC/DC loop (Guide -> Generate -> Verify) independently.

## Trigger

`/sonar-blitz [max-issues]`

Default: fix up to 5 issues. Pass a number to override (e.g. `/sonar-blitz 10`).

## Architecture

```
/sonar-blitz (orchestrator)
    │
    ├── Query all open issues, group by file
    │
    ├── issue-fixer agent (scoring.py)           ── parallel
    ├── issue-fixer agent (sonarqube_client.py)  ── parallel
    ├── issue-fixer agent (api.ts)               ── parallel
    │
    └── Collect results, produce summary
```

## Steps

### Step 1 — Gather all issues

Call `search_sonar_issues_in_projects` with `issueStatuses: ["OPEN"]`, parsing the project key from CLAUDE.md.

Group issues by file path. Sort files by highest-severity issue (BLOCKER first).

### Step 2 — Fan out issue-fixer agents

For each affected file (up to the max), launch an `issue-fixer` agent using the Agent tool. Include in each agent's prompt:
- All issues in that file (issue key, rule key, line, message)
- The project key
- Instruction to fix issues in severity order within the file

Launch agents **in parallel** — use a single response with multiple Agent tool calls in the same message. Claude Code executes concurrent Agent tool calls simultaneously. Issues in different files are independent and safe to fix concurrently.

### Step 3 — Collect and report

Wait for all agents to complete. Produce a summary:

```
SONAR BLITZ REPORT
==================
Files targeted: <N>
Issues attempted: <N>

RESULTS
  [FIXED] scoring.py — 1 issue resolved
    - python:S3776: Cognitive complexity refactored (line 32)

  [FIXED] sonarqube_client.py — 1 issue resolved
    - python:S2068: Token moved from query param to Authorization header (line 22)

  [PARTIAL] api.ts — 1 of 2 issues resolved
    - typescript:S2068: localStorage token usage addressed (line 10)
    - typescript:S6958: Fix reverted — introduced new issues

  [FAILED] useHealthScore.ts — fix reverted
    - typescript:S6958: Error state fix introduced new BLOCKER

SUMMARY
  Fixed: <N> issues across <N> files
  Reverted: <N> issues (verification failed)
  Remaining: <N> open issues
```

## Error Handling

- If an agent fails or times out, report the failure and continue with results from other agents
- Never let one file's failure block the entire report
- If no open issues are found, report the project is clean
