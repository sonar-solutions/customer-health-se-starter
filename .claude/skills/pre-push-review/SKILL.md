---
name: pre-push-review
description: >
  Use when the user runs /pre-push-review to run SonarQube analysis on changed files
  before pushing. Triggered by: /pre-push-review or "run sonar before push" or
  "check my code with sonarqube before I push".
tools:
  - Bash
  - Read
  - mcp__sonarqube__search_sonar_issues_in_projects
  - mcp__sonarqube__get_intended_architecture
---

# /pre-push-review — Pre-Push SonarQube Analysis

Runs SonarQube analysis on files changed in the current branch before pushing, catching issues that would otherwise require multiple push-fix cycles. Also checks for architecture violations using the project's intended architecture constraints.

Background: Without this, SonarQube feedback only comes after pushing and waiting for CI, requiring separate commit+push cycles per round of feedback. This skill catches most issues in the same session. Architecture violations in particular are invisible to `sonar verify` (single-file scope) but are caught here via static import analysis against the defined constraints.

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

### 4. Check architecture constraints

Call `get_intended_architecture`. If it returns constraints (non-empty), proceed with architecture checking. If empty or unavailable, skip this step silently.

For each changed code file:

1. Read the file content.
2. Extract all import/require statements.
3. For each import that uses a **relative path** (starts with `./` or `../`):
   - Resolve the import to a project-relative path using the importing file's location.
   - Match the importing file and the resolved target against the constraint patterns.
   - If the dependency is not in the allowed list and the policy is `deny_by_default`, flag it as a MAJOR architecture violation.
4. Skip imports using path aliases (e.g., `@/`, `~`) — note them as unresolved if any are found.

**Matching rules:**
- Constraints use glob patterns with `**` as wildcard and `:`, `.`, `/` as separators.
- A file at `frontend/src/services/api.ts` matches pattern `frontend/src/services/**`.
- An import resolving to `frontend/src/components/ScoreCard.tsx` matches `frontend/src/components/**`.
- If no constraint allows `services/**` → `components/**` and policy is `deny_by_default`, it's a violation.

**Flag violations as:**
```
MAJOR — <importing-file>:<line> — Architecture violation: <importing-layer> → <target-layer> not allowed [tsarchitecture:S7788]
```
Use `tsarchitecture:S7788` for TypeScript/JavaScript files, `pythonarchitecture:S7788` for Python files.

Architecture violations are **deterministic** for standard relative imports — this is rule application, not inference. Path aliases are skipped (potential false negatives, not false positives).

### 5. Analyze each changed file with sonar verify

For each code file identified in step 1:

1. Read the file content using the Read tool to confirm it exists and is a valid code file.
2. If the file is too large to read, skip it and record it in a "skipped files" list with the reason.
3. Run `sonar verify --file <relative-file-path> --branch <branch-name> --project <project-key>` via Bash.
4. Collect all issues returned. If the command returns an error for a specific file, record the error and continue — do not abort the entire review.

### 6. Aggregate and categorize issues

Merge all issues from steps 4 and 5. Sort into severity tiers:

| Tier | Severities | Action |
|------|-----------|--------|
| BLOCKER / CRITICAL | BLOCKER, CRITICAL | Must fix before pushing |
| MAJOR | MAJOR | Should fix; warn prominently |
| MINOR / INFO | MINOR, INFO | Informational; do not block |

### 7. Report results

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
- frontend/src/services/api.ts:3 — Architecture violation: services → components not allowed [tsarchitecture:S7788]
- src/utils.py:15 — Cognitive complexity too high [python:S3776]

MINOR:
- src/models.py:8 — Missing docstring [python:S1135]

Verdict: DO NOT PUSH until BLOCKER issues are resolved.
```

If there are unresolved path aliases, append:
```
Note: <N> path-alias import(s) not checked for architecture violations (tsconfig aliases not resolved).
```

If there are no issues in a severity tier, omit that section entirely.

If there are skipped files or per-file errors, append them at the end.

Update the verdict based on what was found:
- BLOCKER or CRITICAL issues present: `Verdict: DO NOT PUSH until BLOCKER issues are resolved.`
- Only MAJOR issues: `Verdict: PUSH WITH CAUTION — MAJOR issues should be addressed.`
- Only MINOR / INFO issues: `Verdict: Safe to push. Minor issues noted above for awareness.`
- No issues: `Verdict: Safe to push.`

### 8. Fallback if SonarQube CLI is unavailable

If `sonar verify` fails or the `sonar` CLI is not installed, fall back to a manual review:

1. Run `git diff HEAD` to get the full diff of changed files.
2. Scan the diff manually for the most common SonarQube issue patterns:
   - Hardcoded credentials (passwords, tokens, API keys in string literals)
   - SQL injection patterns (string concatenation in queries)
   - TODO / FIXME / HACK comments
   - Overly long methods or deeply nested blocks
   - Missing null/error checks in critical paths
3. Still perform the architecture check from step 4 (it uses MCP, not the CLI).
4. Report any findings in the same format as step 7.
5. Prepend the report with a prominent notice:

```
NOTE: SonarQube CLI was unavailable. This is a degraded manual review —
it does not replace a real SonarQube scan. Architecture check was still performed.
```
