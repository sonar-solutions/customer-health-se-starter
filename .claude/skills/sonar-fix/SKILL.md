# /sonar-fix

Autonomously fix the highest-severity open SonarQube issue in the current project.

## Trigger
`/sonar-fix [issue-key-or-description]`

## Behavior

### Step 1 — Find the issue
If an issue key was provided (e.g. `/sonar-fix AZVE-RftdL8DeK7ITSGh`), use that directly.

Otherwise, query the SonarQube MCP for the highest-severity open issue in the current project:
- Use `mcp__sonarqube__search_sonar_issues_in_projects` with `issueStatuses: ["OPEN"]`
- Determine the current project key from `CLAUDE.md` or `.github/workflows/*.yml`
- Prioritize: BLOCKER > CRITICAL > MAJOR

### Step 2 — Understand the rule
Call `mcp__sonarqube__show_rule` with the issue's rule key to get the full remediation guidance before touching any code.

### Step 3 — Read the file
Read the affected file at the reported line. Understand the surrounding context before making changes.

### Step 4 — Fix it
Apply the fix following the SonarQube rule's remediation guidance. Keep changes minimal and targeted — only fix what the rule requires.

### Step 5 — Verify
Run `sonar verify <file-path>` using the sonar CLI to confirm the specific issue is resolved:
```
export PATH="/Users/theil.bise/.local/share/sonarqube-cli/bin:$PATH"
sonar verify <file-path>
```

### Step 6 — Report
Output a concise summary:
- Issue key and rule
- File and line
- What was changed (1-2 sentences)
- Verify result (pass/fail, any remaining issues in that file)

## Notes
- Do not fix multiple issues in one invocation — one issue, one focused fix
- If `sonar verify` reports new issues introduced by the fix, revert and try a different approach
- If the fix requires understanding upstream callers or architecture, use `mcp__sonarqube__search_sonar_issues_in_projects` to check related files first
