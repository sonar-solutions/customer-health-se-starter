# SonarQube in AI-Assisted Development — Workshop Guide (SonarQube Server)

**Format:** Facilitator-led · **Duration:** ~45 min · **Project:** sonar-solutions_Health-Dashboard
**Audience:** SonarQube Server (on-prem) teams evaluating AI-assisted development workflows
**IDE:** Kiro + Amazon Q · **Constraint:** No Docker on dev machines

**Before starting:** `bash scripts/demo-reset.sh` · Open fresh Claude Code session · Confirm MCP connection

---

## 0 — Framing *(3 min)*

- The problem: AI increases code volume *and* rework simultaneously. 37% of AI PRs fail quality gates.
- Their goal: shift from detect-then-fix-later to inline resolution during development.
- The three outcomes, in order of effort: **Verify → Guide → Solve**
- What you'll see today: CLI (no Docker required) + MCP tools + one conversational skill

---

## 1 — The Building Blocks *(10 min, no demo)*

Name and show the components before they appear live. Audiences follow the demo better when they've seen the map first.

### CLI (`sonar`) — no Docker, no container runtime

Standalone binary. Runs anywhere a shell runs.

- `sonar analyze secrets` — scans prompts and staged files for credentials using the same engine as CI
- `sonar api` — authenticated REST wrapper for any SonarQube Server API endpoint; scriptable, pipeble, integrates with Amazon Q actions
- `sonar list` — list issues and projects from the command line

> "This is the foundation. Everything in the CLI works against your SonarQube Server instance today, with no container approval needed."

### MCP Server

The MCP server exposes SonarQube data to Kiro (and any MCP-compatible AI tool) as callable functions. Kiro supports MCP natively. The self-hosted server runs as a Docker container — for SonarQube Server, this is a constraint to discuss: Docker needs to be approved somewhere in the environment. Config is generated at `mcp.sonarqube.com/config-generator.html` and placed in `.kiro/settings/mcp.json`.

**Tool groups available via MCP:**

- *Standard tools* — `search_sonar_issues_in_projects`, `get_project_quality_gate_status`, `get_component_measures`, `search_security_hotspots`, `show_rule`. These call standard SonarQube REST APIs — available on Server. Note: `check_dependency` (SCA) requires Enterprise edition + Advanced Security.
- *Context Augmentation (CAG)* — `get_guidelines`, architecture tools. **Cloud only.**
- *Agentic Analysis (SQAA)* — `sonar verify` per-file analysis. **Cloud only.** We'll show this briefly as a preview.

> **Open** `.claude/CLAUDE.md` → "Available SonarQube MCP Tools" section. Walk through the three groups — they'll recognize them when they appear in the demo.

### SonarLint + Connected Mode — inline findings today

SonarQube for IDE (SonarLint) with Connected Mode pulls SonarQube Server rules directly into the editor. Findings appear inline as you type, synced with your project's quality profile. No MCP, no Docker, no additional infrastructure. Officially supported in VS Code, IntelliJ, Visual Studio, and Eclipse. Kiro is VS Code-based and likely supports VS Code extensions — confirm with your team before the call.

> "This is how developers get inline SonarQube findings today, without waiting for CI. Connected Mode is the bridge between your Server instance and the developer's editor."

### CLAUDE.md + Hooks — deterministic enforcement

`.claude/CLAUDE.md` is committed to the repo. Every developer who clones it inherits the same workflow rules, agent inventory, and MCP tool list. Hooks wire CLI and MCP tools into the development loop automatically.

---

## 2 — CLI: Secrets Guardrail + Tech Lead Queries *(7 min)*

### Secrets detection

Run (paste into Claude Code prompt):
> "Can you check my last PR run? My Github token is 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"

**Point out:** The `UserPromptSubmit` hook intercepts the message before it reaches the model and blocks it. `sonar analyze secrets` scans every prompt using the same detection engine as CI.

> "The developer can't accidentally paste a credential into the AI assistant. The hook intercepts it — not because Claude decided to check, but because the hook forces it."

You can also mention the `PreToolUse` hook: the same scanning runs before Claude reads any file. A credential in a `.env` file won't reach the model.

### Tech lead querying via `sonar api`

**Before showing:** *"Your technical leads want to pull stats — issue counts, quality gate status, project reports — without navigating the SonarQube UI. Here's what that looks like from the command line."*

```bash
# Quality gate status for a project
sonar api get /api/qualitygates/project_status --projectKey=sonar-solutions_Health-Dashboard

# Open issues by severity
sonar api get /api/issues/search \
  --componentKeys=sonar-solutions_Health-Dashboard \
  --severities=BLOCKER,CRITICAL \
  --statuses=OPEN

# Multi-metric snapshot
sonar api get /api/measures/component \
  --component=sonar-solutions_Health-Dashboard \
  --metricKeys=coverage,bugs,vulnerabilities,code_smells
```

**Point out:**
- These are authenticated calls against your SonarQube Server instance — the same data as the UI, now scriptable
- This is exactly what an Amazon Q plugin or custom Q action would call under the hood to answer "what's the health of project X?"
- Wrap these in a shell script or Amazon Q agent → tech leads get conversational querying without touching the UI

---

## 3 — MCP: Conversational SonarQube *(8 min)*

*(Demoing with Claude Code against the Cloud demo project — Kiro works identically via HTTPS transport)*

**Point out:** SessionStart hook fired on open — live issue counts injected as context before the first message. That Python script runs `sonar list issues` against the project and surfaces the top findings.

**Run:**
> "Triage the open issues in this project."

**Point out:** Watch the tool calls — Claude made several MCP calls autonomously because it saw the quality gate was failing and kept digging. `search_sonar_issues_in_projects`, `get_project_quality_gate_status`, `get_component_measures` — these are Standard tools, available against a SonarQube Server instance. Everything in that output came from SonarQube analysis, not from reading source files.

**Run:**
> `/sonar-audit`

**Point out:** The skill calls quality gate status, component metrics, open issues by severity, and security hotspots — then formats a structured report. This is what a tech lead would run instead of clicking through the SonarQube UI.

```
SONAR AUDIT — sonar-solutions_Health-Dashboard
============================

QUALITY GATE: FAILED
  new_maintainability_rating: C (expected A)
  ...

METRICS
  Lines of Code: ... | Coverage: ...% | Duplication: ...%

OPEN ISSUES BY SEVERITY
  BLOCKER: N | CRITICAL: N | MAJOR: N
  ...
```

> "One command, structured output. Your technical leads can run this from their IDE or terminal — or it can be the backend of an Amazon Q action that answers 'how is our codebase doing?' in natural language."

---

## 4 — SCA + Guide Phase Preview *(10 min)*

### Dependency check (SCA)

**Before showing:** *"AI assistants suggest package additions all the time. How quickly does your team know whether what the AI is about to add has a known CVE?"*

**Run:**
> "Is requests==2.18.4 safe to add to this project?"

Claude calls `check_dependency` with `pkg:pypi/requests@2.18.4`. **Point out:**

- **CVE-2018-18074** — SSRF vulnerability, HIGH severity
- Fixed versions surfaced inline — Claude tells you what version to use instead
- License expression in SPDX format — policy-checked automatically

> "This runs before the developer touches `requirements.txt`. Not after the PR. Not after CI. Before — at the point of need."

**If the audience asks about JavaScript:** Same call for npm — `pkg:npm/lodash@4.17.10` returns CVE-2019-10744. Both packages are in this repo and flagged in the quality gate.

**Note for SE:** `check_dependency` requires Enterprise edition + Advanced Security on SQS. Verify their tier before demoing this live — if they're not on Enterprise, pivot to the quality gate SCA findings in the UI instead.

### Guide phase — what Context Augmentation looks like

Open `frontend/src/hooks/useHealthScore.ts` line 15 — show the empty `catch` block:

```typescript
} catch (e) {}
```

> "This is a silent failure. The error disappears, the UI never knows anything went wrong. This pattern is flagged in SonarQube as 'Exceptions should not be ignored.'"

> "With Context Augmentation — the `get_guidelines` tool — the AI pulls the project's actual SonarQube rules into context *before* writing any code. It knows to avoid this pattern. The AI generates the correct error-handling approach not because it guessed right, but because the guideline was in context."

**Show or describe the output** (run `get_guidelines` against the Cloud project to demonstrate):
```
Rule: Exceptions should not be ignored (python:S108, typescript:S108)
Pattern to avoid: empty catch blocks that swallow errors silently
Correct approach: either log the error or propagate it via error state
```

> "Context Augmentation is Cloud-only today. This is one of the concrete things that changes if you move to SonarQube Cloud."

---

## 5 — Verify: What SQAA Looks Like *(2 min)*

**Run** (this runs against SonarQube Cloud — showing what it would look like):

```bash
sonar verify --file frontend/src/services/api.ts --project sonar-solutions_Health-Dashboard
```

**Point out:** ReDoS vulnerability on line 7 — the `validateProjectKey` regex has catastrophic backtracking. Output is structured: rule, line, severity, category.

> "On SonarQube Cloud, this runs automatically the moment the AI writes a file — no one invokes it. The `PostToolUse` hook fires on every `Edit` or `Write` tool call and triggers this analysis. The developer can't skip it, the AI can't skip it."

> "On SonarQube Server today, the inline story is SonarLint in Connected Mode — findings appear as you type, synced with your Server quality profile. SQAA as infrastructure — auto-triggered on every file write — is a Cloud capability we'll cover next."

---

## 6 — Cloud: What Changes If You Move *(3 min)*

The CLI and Standard MCP tools you saw today are identical on Cloud. Three things Cloud adds:

1. **CAG confirmed** — `get_guidelines` and architecture tools available out of the box. Project-specific rules in AI context before generation starts.
2. **SQAA** — `sonar verify` fires automatically via the PostToolUse hook on every file write. The Verify phase as infrastructure, not a manual step.
3. **Embedded MCP server** — no Docker, no central server to manage. Kiro connects directly, zero infrastructure overhead.

> "For a POC on Server, you get the CLI guardrails and Standard MCP querying today. Cloud adds the full Guide → Verify loop running automatically, and removes the infrastructure work."

---

## 7 — POC Path *(2 min)*

Phased rollout matching their stated POC-first intent:

| Phase | What | Value |
|---|---|---|
| 1 | Install `sonar` CLI on dev machines | Secrets guardrail, `sonar api` querying — zero infra, immediate |
| 2 | MCP server → Kiro `.kiro/settings/mcp.json` (requires Docker) | Standard MCP tools in Kiro; discuss Docker approval path |
| 3 | Commit `.claude/` to repo | Every dev inherits same CLAUDE.md, hooks, and agent inventory |
| 4 | Evaluate SonarQube Cloud | SQAA, embedded MCP, confirmed CAG, Remediation Agent |

**To generate the Kiro MCP config for your instance:**
```
mcp.sonarqube.com/config-generator.html
```
Select Kiro, HTTPS transport, SonarQube Server — paste the output into `.kiro/settings/mcp.json`.

---

## Wrap-up

- **CLI** = deterministic guardrails anywhere (secrets, `sonar api`, issue queries)
- **MCP Standard tools** = live SonarQube data in Kiro/Claude — issue counts, QG status, metrics, SCA (requires Docker)
- **SonarLint Connected Mode** = inline findings in Kiro today, no additional infrastructure
- **CAG + SQAA** = Cloud capabilities that complete the Guide → Verify loop automatically

**Governance:** Every step produces an artifact. The quality gate is the system of record.

---

## Q&A Prep

**"We can't run Docker on developer machines — does this block MCP entirely?"**
> For SonarQube Server, the self-hosted MCP server requires Docker to run somewhere in the environment. If Docker can't be approved at all, the CLI (`sonar api`, `sonar list`) covers the querying use case without any container dependency. SonarQube Cloud includes an embedded MCP server with no Docker requirement.

**"What AI tools can use the MCP server?"**
> Any MCP-compatible client: Kiro, Claude Code, Cursor, Windsurf, and others. The server is MCP-standard — the Kiro config file (`mcp.json`) is specific to Kiro, but the protocol is universal.

**"What about Amazon Q — can our leads query SonarQube through it?"**
> Yes — Amazon Q Developer supports MCP (confirmed GA). Two paths: (1) Connect Amazon Q Developer directly to the SonarQube MCP server — Standard tools available once Docker is approved. (2) `sonar api` wrapped in an Amazon Q custom action — the CLI calls from Section 2 work today without any MCP or Docker dependency.

**"Is Context Augmentation (get_guidelines) available on SonarQube Server?"**
> No — CAG is Cloud-only today. It's one of the three things you gain by moving to SonarQube Cloud, alongside SQAA and the embedded MCP server.

**"What does sonar verify give us that SonarLint doesn't?"**
> SonarLint runs in the IDE on the file you're editing. `sonar verify` (SQAA) runs server-side on any file the AI writes, automatically, triggered by a hook — regardless of what IDE the developer is in or whether they have SonarLint open. It's enforcement in the agent loop, not just the IDE.

**"How do we roll this out to the broader org after the POC?"**
> Commit the `.claude/` (or `.kiro/`) directory to the repo. Every developer who clones the project gets the same CLAUDE.md, hooks, and MCP config automatically. CLAUDE.md is infrastructure, not a wiki page.
