# AC/DC Demo Guide — Claude Code + SonarQube MCP

**Audience:** Engineering teams evaluating AI-assisted development workflows
**Repo:** Health-Dashboard (sonar-solutions org)
**Project key:** sonar-solutions_Health-Dashboard

--------

## Pre-Demo Checklist (15 min before)

- [ ] `sonar --version` passes (CLI on PATH)
- [ ] `SONAR_TOKEN` set in shell (used by CLI and scan action)
- [ ] Run `bash scripts/demo-reset.sh` — restores clean main, confirms all 6 intentional issues are present
- [ ] Start a fresh Claude Code session in this repo directory (SessionStart hook fires on open)
- [ ] Verify hook fired — you should see a status message with live issue counts from SonarQube
- [ ] Open this file in a second tab
- [ ] Have the AC/DC blog post ready: https://www.sonarsource.com/blog/the-future-is-ac-dc-the-agent-centric-development-cycle/

--------

## Framing (5 min — use for all tracks)

**Say:**

> "You're already using AI coding tools. The question is: where does AI end
> and human review begin?
> Sonar's AC/DC framework — Agent Centric Development Cycle — gives you four phases:
> **Guide, Generate, Verify, Solve**.
> Your CI is the outer loop. What we're about to show is the **inner loop** —
> what happens before a PR is ever created."

**Draw/show:**

```
Guide → Generate → Verify → Solve
```

> "This cycle runs at two levels. The **inner loop** is real-time — happening
> inside each agentic reasoning step, micro-corrections as the agent works,
> before any human ever sees the output. The **outer loop** is your CI pipeline —
> comprehensive verification once the agent finishes. What we're going to show
> is how Sonar powers the inner loop. By the time code reaches CI, the issues
> are already gone."

**Then:** "What I'm going to show you depends on where you are in your AI adoption journey.
This repo has everything from basic guardrails to autonomous multi-agent workflows."

--------

## Choose Your Track

| Track | Maturity | Audience | Time | What You'll Show |
|-------|----------|----------|------|-----------------|
| **A: Guardrails** | Early / AI-cautious | Security-first, compliance-heavy | 15 min | Hooks, CLAUDE.md, `/pre-push-review`, `/sonar-audit` |
| **B: AI-Assisted Dev** | Adopting | Teams using Copilot/Claude for generation | 20 min | CAG guidelines, code generation, `/sonar-fix` |
| **C: Autonomous Agents** | Scaling | Teams adopting agentic workflows | 20 min | `/sonar-blitz`, `/tech-debt-sprint`, `/arch-guard` |
| **D: Custom Agent Patterns** | Platform-native | Platform engineering teams | 20 min | `/security-posture`, `/sonar-onboard`, agent anatomy |

> **SE note:** Don't show the Maturity column to the customer. Use "where are you in your AI adoption journey?" framing instead. Tracks A+B is the most common pairing for mid-maturity teams. You can run A→B→C→D for a full 75-min deep dive.

--------

## Track A: Guardrails & Gates (15 min)

**For:** Security-first teams, compliance-heavy orgs, "we're nervous about AI" audiences.
**AC/DC Phase:** Primarily Guide and Verify.
**Key message:** "Even with zero AI autonomy, SonarQube prevents AI from reading secrets, committing vulnerabilities, or ignoring quality standards."

### A1 — Session Start Hook

> "Before I type a single prompt, watch what happens when Claude Code opens this project."

Point to the status bar message from the SessionStart hook — it should show live BLOCKER/CRITICAL counts from the SonarQube project.

> "That's a Python script in `.claude/hooks/session-start.py`. It runs the SonarQube CLI,
> pulls live issue counts, and injects them as system context before my first message.
> Every session starts with a current view of the project's health."

### A2 — CLAUDE.md Walkthrough

Open `.claude/CLAUDE.md` and walk through:

1. **Mandatory workflow** — `get_guidelines` before editing, `run_advanced_code_analysis` after, quality gate check before commit
2. **Intentional issues table** — show the 6 issues: two security hotspots (Python + TypeScript), code smell, bug, two SCA CVEs across both languages
3. **Agent inventory** — 7 domain agents available, each with a single responsibility

> "This file is committed to the repo. Every developer who clones this project gets the
> same behavioral baseline — same rules, same workflow, same SonarQube integration.
> It's not a wiki page no one reads. It's infrastructure."

### A3 — Secrets Detection Hook

Type a prompt that includes a fake credential:

```
Can you check my last PR run? My Github token is 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
```

The `UserPromptSubmit` hook runs `sonar analyze secrets` on the prompt before it's sent. If the token pattern matches, the hook blocks the message.

> "The `sonar` CLI runs on every prompt before it reaches the model. The hook intercepts
> it, scans it for secrets, and blocks the message if it finds a match — using the same
> detection engine as your CI pipeline."

Also demonstrate the PreToolUse hook:

> "The same scanning runs before Claude reads any file. If `sonar analyze secrets` finds
> a credential in a file you're about to read, the hook blocks the file read."

### A4 — Pre-Push Review

Run `/pre-push-review`.

Expected findings:
- `backend/app/clients/sonarqube_client.py` — token passed as query parameter (Security Hotspot)
- `backend/app/services/scoring.py` — cognitive complexity > 15 (Code Smell)
- `backend/requirements.txt` — `requests==2.18.4` (SCA — CVE-2018-18074)
- `frontend/src/services/api.ts` — token stored in localStorage (Security Hotspot)
- `frontend/src/hooks/useHealthScore.ts` — missing error state / unhandled rejection (Bug)
- `frontend/package.json` — `lodash@4.17.10` (SCA — CVE-2019-10744)

> "Six findings across Python and TypeScript in one scan — two languages, one quality gate.
> The verdict: **do not push**. This is what the inner loop catches before CI ever runs."

### A5 — Quick Audit

Run `/sonar-audit`.

> "This is a lightweight read-only audit — no code changes, just a snapshot. Works in
> read-only environments where you can't run a full agent workflow."

**Track A close:**

> "What you just saw: hooks that enforce secrets hygiene, a committed behavioral baseline
> that every developer inherits, and quality analysis that runs before the PR is ever created.
> Zero AI autonomy required — just guardrails."

--------

## Track B: AI-Assisted Dev (20 min)

**For:** Teams already using Copilot or Claude for code generation.
**AC/DC Phase:** Guide → Generate → Verify.
**Key message:** "AI generates better code when SonarQube's project-specific rules are in context before generation starts."

### B1 — Guide Phase: Pull Guidelines

```
Before we write any code, pull the current guidelines for this project.
```

Claude calls `get_guidelines` with `mode: "project_based"`. Point out:

- Rules are derived from **this project's actual issue history**, not a generic catalog
- Python-specific rules: token in query params, vulnerable dependency patterns, cognitive complexity thresholds
- TypeScript-specific rules: localStorage usage, unhandled promise rejections

> "These aren't generic best practices. SonarQube analyzed this codebase and surfaced the
> rules most relevant to *our* patterns. The AI now knows what to avoid before it types a
> single character."

### B2 — Generate Phase: Write New Code

```
Add a method to SonarQubeClient that fetches project metrics (lines of code, coverage, duplications).
```

Watch whether Claude generates with `headers={"Authorization": f"Bearer {token}"}` instead of the `params["token"]` pattern that exists in the current code. The guidelines should steer it toward the correct pattern.

> "The AI didn't repeat the existing bad pattern. It used the correct approach because the
> guidelines were in context. That's the Guide phase working."

### B3 — Verify Phase

After generation:

```
Run advanced code analysis on the file you just edited.
```

Claude calls `run_advanced_code_analysis` with the file content — same analysis engine as CI, running in real time.

> "We're verifying inside the agentic loop — not waiting for CI. The outer loop becomes a
> backstop, not the first line of defense."

### B4 — Solve Phase: Fix a Real Issue

```
/sonar-fix
```

This delegates to the `issue-fixer` agent, which runs the full AC/DC loop on the highest-severity open issue:
1. Calls `get_guidelines` and `show_rule` to understand the fix
2. Edits the file
3. Calls `run_advanced_code_analysis` to verify the fix didn't introduce new issues

**Track B close:**

> "Guide, Generate, Verify, Solve — one developer, one session, real-time quality enforcement.
> The SonarQube MCP is the connective tissue between every step."

--------

## Track C: Autonomous Agents (20 min)

**For:** Teams adopting agentic workflows at scale.
**AC/DC Phase:** Full AC/DC loop, automated.
**Key message:** "The same AC/DC loop that one developer runs manually can be scaled across an entire codebase with parallel agents."

### C1 — Multi-Issue Blitz

```
/sonar-blitz
```

This fans out parallel `issue-fixer` agents — one per affected file. With 4-5 files having issues (both Python and TypeScript), you'll see multiple agents working simultaneously.

> "Each agent runs the full AC/DC loop independently. The orchestrator collects results and
> reports which issues were fixed, which need human review. Ten minutes of autonomous work
> compressed into one command."

### C2 — Tech Debt Sprint

```
/tech-debt-sprint
```

Two-wave pattern:
1. `metrics-analyzer` + `debt-hotspot-finder` run in parallel — surface coverage gaps, complexity hotspots, file-level debt density
2. `blast-radius-tracer` takes the top hotspots and maps their upstream callers

> "Domain story: this is a health scorecard app. Its own code health needs fixing.
> The tech debt sprint gives you a prioritized attack plan — which files to fix first
> based on where changes will have the most impact."

### C3 — Architecture Guard

```
/arch-guard
```

Validates:
- **Backend:** `api` → `services` → `repositories`/`clients` (enforced by import-linter in CI)
- **Frontend:** `pages` → `components`/`hooks`/`services`, no reverse imports (enforced by dependency-cruiser)

> "The architecture constraints aren't just documentation — they're enforced in CI and
> verified here by the `architecture-analyzer` agent using SonarQube's architecture graph.
> Two languages, one consistent constraint model."

**Track C close:**

> "Same agents, same SonarQube rules, same AC/DC loop — now running autonomously across
> the whole codebase. This is what 'scaling AI-assisted development' actually means."

--------

## Track D: Custom Agent Patterns (20 min)

**For:** Platform engineering teams who want to build their own agent workflows.
**AC/DC Phase:** All phases, custom-composed.
**Key message:** "Agents and skills are just markdown files committed to the repo — your platform team owns them."

### D1 — Security Posture

```
/security-posture
```

Three-agent wave:
1. `attack-surface-mapper` — finds all public API endpoints and entry points in the codebase
2. `vulnerability-correlator` — inventories open security issues and hotspots with CWE mappings; picks up both CVEs (CVE-2018-18074, CVE-2019-10744)
3. `data-flow-tracer` — traces call paths from entry points to vulnerable code

> "The SCA findings are concrete: `requests==2.18.4` in Python and `lodash@4.17.10` in
> TypeScript. Both flagged with CVE numbers, both in the same quality gate. One command,
> full attack surface mapped."

### D2 — Onboarding Assessment

```
/sonar-onboard
```

Three agents run in parallel:
- `architecture-analyzer` — maps module structure and constraint compliance
- `metrics-analyzer` — coverage, complexity, duplication, quality gate status
- `debt-hotspot-finder` — top 10 files by bug/smell density

Produces a briefing a new developer (or SE) can use to understand the codebase in 5 minutes.

> "Practical use case: you just got assigned to a new account's codebase. Run this before
> the first call. You'll know more about their quality posture than their own team."

### D3 — Agent Anatomy Walkthrough

Open `.claude/agents/vulnerability-correlator.md` and walk through the structure:

- **YAML frontmatter** — `name`, `description`, `tools` (restricted tool list), `model`
- **Body** — system prompt with step-by-step instructions and output format
- **Tool restrictions** — this agent can search and read but not edit. The `issue-fixer` can edit and run bash. Restrictions are enforced by the runtime.

> "Every agent is a markdown file. Your platform team writes them, commits them, PRs them.
> Any developer who opens the project gets them automatically."

Show the 7-agent inventory table from `.claude/CLAUDE.md`.

**Track D close:**

> "Platform team defines agents. Developers invoke skills. Both are version-controlled,
> PR-reviewable, auditable. This is how you operationalize AI quality standards at scale."

--------

## Before/After Branch Demo (insert in any track)

```bash
git checkout demo/bad-state   # export endpoint with path traversal vuln — quality gate failing
git checkout demo/fixed-state # all issues resolved — quality gate passing
```

In either branch, run:
```
What is the current quality gate status for this project?
```

Claude calls `get_project_quality_gate_status`. Show the difference.

> "PR #1 is open against main — a new export endpoint with a path traversal vulnerability.
> The quality gate is blocking the merge. That's the outer loop working.
> On `demo/fixed-state`, the same check passes."

--------

## Closing

**Say:**

> "What you just saw:
>
> - **CLAUDE.md** — standing instructions committed to the repo, same baseline for every developer and every session
> - **Hooks** — secrets scanning, session context, automatic quality awareness
> - **Skills** — orchestrated workflows from quick audits to multi-agent assessments
> - **Agents** — granular building blocks with tool restrictions and focused responsibilities
> - **SonarQube MCP** — the verification backbone powering every phase of AC/DC
>
> Every phase of AC/DC — Guide, Generate, Verify, Solve — no new UI, no workflow change.
> SonarQube becomes invisible infrastructure inside your AI coding workflow."

--------

## Q&A Prep

**"What is Context Augmentation exactly?"**
> SonarQube's product that uses MCP to inject your project's live quality rules and architectural context into AI agents before they write code. Rules come from SonarQube's analysis of your actual codebase — not a generic catalog.

**"Does this require SonarQube Cloud Enterprise?"**
> Context Augmentation and Agentic Analysis are in open beta as of March 2026. Check with your account team for packaging details.

**"Can this work with Cursor/Copilot too?"**
> The SonarQube MCP server is MCP-standard — works in Cursor, Windsurf, any MCP-compatible agent. The skills and agent definitions shown here are Claude Code-specific, but the MCP integration is universal.

**"What about on-prem SonarQube Server?"**
> MCP server supports SonarQube Server — point `SONARQUBE_URL` at your instance instead of sonarcloud.io. The embedded MCP server (no Docker required) is available on SonarQube Cloud.

**"How do we roll this out?"**
> Commit `.claude/` directory to the repo. Every developer who opens the project gets agents, skills, and hooks automatically. The agents-as-building-blocks pattern means your platform team defines the standards and developers consume them.

**"How does an individual developer get started?"**
> SonarSource ships an official Claude Code plugin that handles setup in two commands:
> ```
> /plugin marketplace add SonarSource/sonarqube-agent-plugins
> /plugin install sonarqube@sonar
> ```
> Then run `/sonarqube:integrate` — it installs the CLI, authenticates, and wires up the MCP server and secrets scanning automatically.

--------

## If Things Go Wrong

| Problem | Fix |
|---------|-----|
| SessionStart hook didn't fire | `/exit` and reopen — hook only fires at session start |
| MCP not connected | Run `/mcp`, check sonarqube is green. Verify `SONAR_TOKEN` is set |
| `get_guidelines` returns empty | Try `mode: "combined"` with `categories: ["Secrets & Cryptography", "Web Security"]` |
| Agent fails or times out | Multi-agent skills degrade gracefully — proceed with available data |
| `/pre-push-review` finds 0 files | Run `bash scripts/demo-reset.sh` |
| Issues already fixed by a skill | Run `bash scripts/demo-reset.sh` to restore main |
| `/arch-guard` shows no constraints | Expected on first run — the skill recommends constraints instead |
| `sonar` not found | `export PATH="$HOME/.local/share/sonarqube-cli/bin:$PATH"` |
| Secrets hook didn't block | Check sonar auth status — needs to be authenticated |
| SCA findings not showing | SCA requires a CI scan — use `demo/bad-state` branch for pre-loaded SCA results |

--------

## Between-Demo Reset

After any demo that involves `/sonar-fix`, `/sonar-blitz`, or manual edits — run this before the next demo:

```bash
bash scripts/demo-reset.sh
```

This resets to clean `origin/main`. The intentional issues are permanently baked in — no re-injection needed.

**Do not push during a demo.** If you accidentally push fixed code to `origin/main`, the issue counts in the SessionStart hook will drop. Restore by re-pushing the original `main` state.

--------

## Appendix: How This Is Built

### Agent Anatomy

```yaml
# .claude/agents/issue-fixer.md
---
name: issue-fixer
description: Fixes a single SonarQube issue with full AC/DC loop.
tools:
  - mcp__sonarqube__get_guidelines
  - mcp__sonarqube__show_rule
  - mcp__sonarqube__run_advanced_code_analysis
  - Read
  - Edit
  - Bash
model: sonnet
---

# System prompt goes here...
```

- **name/description** — used by Claude to decide when to delegate to this agent
- **tools** — tool restrictions. `issue-fixer` can edit code and run bash. `attack-surface-mapper` can only search and read.
- **model** — sonnet for speed, opus for complexity
- **Body** — step-by-step instructions, output format, constraints

### The Pattern

```
Platform Team defines:          Developers invoke:
.claude/agents/                 skills (via /skill-name)
  attack-surface-mapper.md        /security-posture
  vulnerability-correlator.md     /sonar-blitz
  data-flow-tracer.md             /sonar-onboard
  health-analyzer.md              ...
  ...

Both version-controlled, PR-reviewable, auditable.
```

--------

## Appendix: Enterprise Best Practices

### Progression Model

1. **Hooks** — Start here. Secrets scanning, session context, file protection. Zero AI autonomy required.
2. **CLAUDE.md** — Standing instructions. Define the behavioral baseline for Claude — what to check before/after editing. Version-controlled, PR-reviewable.
3. **Skills** — Reusable workflows. `/pre-push-review`, `/sonar-fix` — simple, human-triggered.
4. **Agents** — Specialized building blocks. Define tool restrictions, model choices, output formats.
5. **Multi-Agent Skills** — Orchestration. Skills that compose agents into parallel workflows.

### Key Stats

- **96%** of developers don't fully trust AI-generated code quality (2026 State of Code Developer Survey, 1,100+ respondents)
- Developers **not using SonarQube are 80% more likely** to report AI adoption led to higher frequency of outages
- PRs in agentic workflows are **10x larger** than traditional developer PRs (AC/DC blog, March 2026)
- **37%** of AI-assisted PRs fail quality gates on first submission

### Architecture Principles

- **Consistent verification** — Same SonarQube rules across all AI tools (Claude, Cursor, Copilot)
- **Shared behavioral baseline** — CLAUDE.md committed to the repo, not tribal knowledge
- **Agent restrictions** — Tool-restricted agents prevent AI from doing things it shouldn't
- **Verification loop** — Every code change verified by `run_advanced_code_analysis` before moving on
- **Graceful degradation** — Skills work even when MCP is down

--------

## Appendix: Agent & Skill Reference

### Agents (.claude/agents/)

| Agent | Purpose | Key Tools |
|-------|---------|-----------|
| `attack-surface-mapper` | Map public endpoints and entry points | `search_by_signature_patterns`, `get_current_architecture` |
| `vulnerability-correlator` | Inventory vulns + hotspots with CWE | `search_sonar_issues_in_projects`, `show_rule` |
| `data-flow-tracer` | Trace call-path reachability | `get_upstream/downstream_call_flow` |
| `health-analyzer` | Overall project health summary | `get_component_measures`, `get_project_quality_gate_status` |
| `blast-radius-tracer` | Map upstream callers and dependency impact | `get_upstream_call_flow`, `get_references` |
| `architecture-analyzer` | Check module compliance against constraints | `get_current/intended_architecture`, `get_references` |
| `issue-fixer` | Fix a single issue with full AC/DC loop | `get_guidelines`, `run_advanced_code_analysis`, `Read`, `Edit` |

### Skills

| Skill | Tier | AC/DC | Agents | Pattern |
|-------|------|-------|--------|---------|
| `/sonar-fix` | AI-Assisted | G+G+V | `issue-fixer` | Single delegation |
| `/pre-push-review` | Guardrails | V | (none) | Direct MCP calls |
| `/sonar-audit` | Guardrails | G+V | (none) | Flat skill |
| `/sonar-blitz` | Autonomous | All | `issue-fixer` ×N | Parallel fan-out |
| `/arch-guard` | Autonomous | G+V | `architecture-analyzer` | Single delegation |
| `/tech-debt-sprint` | Autonomous | G | `metrics-analyzer` + `debt-hotspot-finder` → `blast-radius-tracer` | Two-wave |
| `/security-posture` | Custom Agent | All | `attack-surface-mapper` + `vulnerability-correlator` → `data-flow-tracer` | Two-wave |
| `/sonar-onboard` | Autonomous | G | `architecture-analyzer` + `health-analyzer` + `debt-hotspot-finder` | Parallel fan-out |
