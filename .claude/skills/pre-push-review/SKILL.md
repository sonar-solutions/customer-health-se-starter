---
name: pre-push-review
description: >
  Use when the user runs /pre-push-review to run SonarQube analysis on changed files
  before pushing. Triggered by: /pre-push-review or "run sonar before push" or
  "check my code with sonarqube before I push".
tools:
  - Bash
  - Read
  - mcp__sonarqube__run_advanced_code_analysis
  - mcp__sonarqube__search_sonar_issues_in_projects
---

# /pre-push-review — Pre-Push SonarQube Analysis

Runs SonarQube analysis on files changed in the current branch before pushing, catching issues that would otherwise require multiple push-fix cycles.

Background: Without this, SonarQube feedback only comes after pushing and waiting for CI, requiring separate commit+push cycles per round of feedback. This skill catches most issues in the same session.

## Steps

### 1. Get changed files

Run `git diff --name-only HEAD` to list modified files. If that returns nothing, try `git diff --name-only origin/HEAD`, then `git status --short`.

Filter to code files only. Exclude:
- Documentation: `.md`, `.txt`
- Config/data: `.json`, `.yaml`, `.yml`, `.toml`
- Lock files: `package-lock.json`, `yarn.lock`, `Pipfile.lock`, `poetry.lock`, `Gemfile.lock`, etc.
- Non-code assets: images, fonts, binaries

If no changed files are found after filtering, say:

```
No changed files detected. If you have staged changes, try running after `git add`.
```

Then stop.

### 2. Get branch name

Run `git branch --show-current` to get the current branch name. This is informational for the report header.

### 3. Get project key

Look for a `sonar-project.properties` file in the repo root and extract the value of `sonar.projectKey`. If not found, check parent directories up to 2 levels above the repo root.

If the project key is still not found, ask the user:

```
What's your SonarQube project key? (I couldn't find sonar-project.properties in this repo.)
```

If the user does not provide a project key, stop gracefully with:

```
Cannot run pre-push review without a SonarQube project key.
```

### 4. Analyze each changed file

For each code file identified in step 1:

1. Read the file content using the Read tool.
2. If the file is too large to read (Read tool returns an error or the file exceeds a reasonable limit), skip it and record it in a "skipped files" list with the reason.
3. Call `mcp__sonarqube__run_advanced_code_analysis` with:
   - `projectKey`: the project key from step 3
   - `branchName`: the current branch name from step 2
   - `filePath`: the relative file path
   - `fileContent`: the full file content
4. Collect all issues returned. If the call returns an error for a specific file, record the error and continue analyzing the remaining files — do not abort the entire review.

### 5. Aggregate and categorize issues

Sort all collected issues into severity tiers:

| Tier | Severities | Action |
|------|-----------|--------|
| BLOCKER / CRITICAL | BLOCKER, CRITICAL | Must fix before pushing |
| MAJOR | MAJOR | Should fix; warn prominently |
| MINOR / INFO | MINOR, INFO | Informational; do not block |

### 6. Report results

**If no issues found:**

```
Pre-push review: CLEAN
Branch: <branch-name>
Analyzed <N> files, 0 issues found. Safe to push.
```

**If issues found:**

```
Pre-push review: ISSUES FOUND
Branch: <branch-name>
Analyzed <N> files.

BLOCKER (must fix before pushing):
- src/auth.py:42 — Hardcoded credential [python:S2068]

MAJOR (should fix):
- src/utils.py:15 — Cognitive complexity too high [python:S3776]

MINOR:
- src/models.py:8 — Missing docstring [python:S1135]

Verdict: DO NOT PUSH until BLOCKER issues are resolved.
```

If there are no issues in a severity tier, omit that section entirely.

If there are skipped files or per-file errors, append them at the end:

```
Skipped (too large):
- src/generated/big_file.py

Errors during analysis:
- src/legacy.py — SonarQube returned: <error message>
```

Update the verdict based on what was found:
- BLOCKER or CRITICAL issues present: `Verdict: DO NOT PUSH until BLOCKER issues are resolved.`
- Only MAJOR issues: `Verdict: PUSH WITH CAUTION — MAJOR issues should be addressed.`
- Only MINOR / INFO issues: `Verdict: Safe to push. Minor issues noted above for awareness.`
- No issues: `Verdict: Safe to push.`

### 7. Fallback if SonarQube MCP is unavailable

If the `mcp__sonarqube__run_advanced_code_analysis` tool call fails or is not available at all, fall back to a manual review:

1. Run `git diff HEAD` to get the full diff of changed files.
2. Scan the diff manually for the most common SonarQube issue patterns:
   - Hardcoded credentials (passwords, tokens, API keys in string literals)
   - SQL injection patterns (string concatenation in queries)
   - TODO / FIXME / HACK comments
   - Overly long methods or deeply nested blocks
   - Missing null/error checks in critical paths
3. Report any findings in the same format as step 6.
4. Prepend the report with a prominent notice:

```
NOTE: SonarQube MCP was unavailable. This is a degraded manual review —
it does not replace a real SonarQube scan. Push with awareness that
automated analysis was not performed.
```
