---
name: sonar-watch
description: >
  Post-push quality gate check. Checks CI status, PR-scoped SonarQube quality gate,
  and new issues introduced by the current PR. Recommends targeted sonar-fix calls.
  Triggered by: /sonar-watch, "check the quality gate", "did sonar pass", "check CI results".
tools:
  - Bash
  - mcp__sonarqube__list_pull_requests
  - mcp__sonarqube__get_project_quality_gate_status
  - mcp__sonarqube__search_sonar_issues_in_projects
---

# /sonar-watch — Post-Push Quality Gate Check

Checks CI status and SonarQube quality gate for the current PR. Surfaces only the issues
introduced by this PR, not pre-existing project issues. Recommends `/sonar-fix` calls in
severity order for anything blocking the gate.

## Trigger

`/sonar-watch`

## Steps

### 1. Get PR context

Run `GITHUB_TOKEN="" gh pr view --json number,title,state,headRefName`.

- If command fails or returns no PR: exit with:
  ```
  No open PR on this branch. Push and open a PR first.
  ```

### 2. Check CI viability

Run `GITHUB_TOKEN="" gh pr checks`.

- If no checks returned at all: exit with:
  ```
  No CI checks found on this PR — nothing to watch.
  ```
- Scan output for a check whose name contains `sonar` or `SonarQube` (case-insensitive).
  - If no SonarQube check found: exit with:
    ```
    No SonarQube check in CI for this PR. Ensure the SonarQube scan action is configured in your workflow.
    ```
  - If SonarQube check status is `skipped`: exit with:
    ```
    SonarQube CI check was skipped — quality gate result unavailable.
    ```
  - If SonarQube check is still pending/running: exit with:
    ```
    CI still running — re-run /sonar-watch when complete.
    ```
  - If completed (pass or fail): continue.

### 3. Match PR in SonarQube

Call `list_pull_requests`. Match the PR by comparing the `headRefName` from step 1 against
the branch name on each SonarQube PR entry. Extract the SonarQube PR key (numeric string).

If no match found: exit with:
```
PR branch not found in SonarQube. The CI scan may not have completed yet, or the project
key in sonar-project.properties may be misconfigured.
```

### 4. Fetch quality gate

Call `get_project_quality_gate_status` with `pullRequest: <sonarqube-pr-key>`.

### 5. Fetch new PR issues

Call `search_sonar_issues_in_projects` with `pullRequestId: <sonarqube-pr-key>` and
`issueStatuses: ["OPEN"]`. This returns only issues introduced by this PR.

### 6. Report

```
SONAR WATCH — PR #<N>: <title>
================================
CI:           PASSED / FAILED
Quality Gate: PASSED / FAILED
  <failing condition 1 if any>
  <failing condition 2 if any>

NEW ISSUES ON THIS PR
  BLOCKER:  <N>
  CRITICAL: <N>
  MAJOR:    <N>
  MINOR:    <N>

  1. [BLOCKER] src/auth.py:42 — <message> [rule-key]
  2. [CRITICAL] src/utils.py:15 — <message> [rule-key]

NEXT STEPS
  /sonar-fix <issue-key-1>   ← fix highest severity first
  /sonar-fix <issue-key-2>
```

- If gate passed and no new issues:
  ```
  Quality gate passed. No new issues on this PR. Safe to merge.
  ```
- Omit `NEW ISSUES` and `NEXT STEPS` sections if no issues found.
- Omit severity rows with count 0.
- List issues sorted by severity (BLOCKER → CRITICAL → MAJOR → MINOR), max 10.
