# AC/DC Demo Guide — Claude Code + SonarQube MCP

**Audience:** Engineering teams evaluating AI-assisted development workflows
**Repo:** Health-Dashboard (sonar-solutions org)
**Project key:** sonar-solutions_Health-Dashboard

--------

## Pre-Demo Checklist (15 min before)

- [ ] `sonar --version` passes (CLI on PATH)
- [ ] `SONAR_TOKEN` set in shell (used by CLI and scan action)
- [ ] Run `bash scripts/demo-reset.sh` — restores clean main, confirms all 6 issues are present
- [ ] Start a fresh Claude Code session in this repo directory (SessionStart hook fires on open)
- [ ] Verify hook fired — you should see a status message with live issue counts from SonarQube
- [ ] Verify SonarQube MCP is connected: `/mcp`
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

**Draw/show slide:**

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

1. **Mandatory workflow** — 4 enforcement points: before editing, after editing, before commit,
   before architecture change. Every developer who opens this repo inherits this.
2. **Agent inventory** — specialized agents with scoped tool lists committed to the repo.
   Not tribal knowledge — version-controlled, PR-reviewable infrastructure.
3. **MCP tools section** — CAG (context injection), Agentic (real-time analysis), Standard
   (quality metrics). Three layers, one integration.

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

Claude runs `sonar verify` via the SonarQube CLI — same analysis engine as CI, running in real time.

> "We're verifying inside the agentic loop — not waiting for CI. The outer loop becomes a
> backstop, not the first line of defense."

### B4 — Solve Phase: Fix a Real Issue

```
/sonar-fix
```

This delegates to the `issue-fixer` agent, which runs the full AC/DC loop on the highest-severity open issue:
1. Calls `get_guidelines` and `show_rule` to understand the fix
2. Edits the file
3. Runs `sonar verify` to verify the fix didn't introduce new issues

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
- **Backend:** `api` → `services` → `repositories`/`clients`
- **Frontend:** `pages` → `components`/`hooks`/`services`, no reverse imports (enforced by SonarQube's intended architecture)

> "The architecture constraints aren't just documentation — they're enforced by the SonarQube
> quality gate and visualized here by the `architecture-analyzer` agent.
> Two languages, one consistent constraint model."

> See **C4** for a live push that triggers this constraint in CI.

### C4 — Outer Loop: Live Push + Quality Gate Failure

**Pre-demo:** Run `bash scripts/demo-reset.sh` to reset the branch (auto-detects your GitHub username).

Check out `demo/live-push-<yourname>`. Show `frontend/src/services/api.ts` — the commit adds two
problems: a code style issue (`account && account.projectKey` should use optional chaining) AND
an architecture violation (the services layer imports from the component layer).

Run `sonar verify` on the file first:

```
sonar verify --file frontend/src/services/api.ts --project sonar-solutions_Health-Dashboard
```

> "sonar verify catches the optional-chain code smell — that's the inner loop working. But notice
> what it doesn't flag: the import from `../components`. Importing a UI component into the
> services layer violates the intended architecture. sonar verify analyses this file in isolation —
> it can't see the full dependency graph. That's the gap the outer loop fills."

Now push:

```
git push origin demo/live-push-<yourname>
```

The `posttool-push-watch.sh` hook fires:

> "git push detected — SonarQube CI check running on PR. Invoke /sonar-watch when CI completes."

Once CI completes (~2 min), run `/sonar-watch`:

```
SONAR WATCH — PR #2: Add score refresh to ScoreCard
=====================================================
CI:           PASSED  (tests: backend ✓  frontend ✓)
Quality Gate: FAILED
  new_major_violations: 1 (threshold: 0)

NEXT STEPS
  /arch-guard   ← investigate the full picture
```

Run `/arch-guard` to surface the architecture constraint breach using SonarQube's dependency graph.

> "Two problems in one commit. sonar verify caught the code smell but missed the architecture
> violation — it only sees one file. The quality gate caught the code smell through CI. And
> /arch-guard revealed what even the quality gate can't: the services layer importing from
> components is forbidden by our intended architecture. Three layers of enforcement, each
> catching what the previous one missed."

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
- `health-analyzer` — coverage, complexity, duplication, quality gate status
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

Show the agent inventory table from `.claude/CLAUDE.md`.

### D4 — Skills vs. Agents: Why Both?

> "You might wonder: why have both skills and agents? Why not just use one?"

Walk through the three patterns in this project:

| Pattern | Example | When to use |
|---------|---------|-------------|
| **Skill (inline)** | `/sonar-audit`, `/pre-push-review` | Simple workflows — sequential MCP calls, no need for isolation or parallelism |
| **Skill → 1 agent** | `/sonar-fix`, `/arch-guard` | Need tool restrictions (e.g., isolate edit/bash capability) or context isolation |
| **Skill → N agents** | `/security-posture`, `/sonar-blitz` | Multi-specialist workflows — parallel execution, wave orchestration, result synthesis |

**Three reasons skills delegate to agents:**

1. **Tool restrictions** — `attack-surface-mapper` can only search and read. `issue-fixer` can edit files and run bash. The skill orchestrates; agents are sandboxed to their capabilities.
2. **Context isolation** — each agent gets a fresh context window. A 3-agent security assessment would bloat the main conversation with all intermediate search results. Agents keep that noise out.
3. **Parallelism** — agents run concurrently. `/security-posture` runs attack-surface-mapper and vulnerability-correlator simultaneously in wave 1, then feeds both results to data-flow-tracer in wave 2.

**Three reasons skills exist on top of agents:**

1. **Orchestration** — agents are single-responsibility; skills compose them into multi-step workflows with wave ordering.
2. **Discoverability** — `/security-posture` shows up in tab-completion. Agents don't.
3. **Synthesis** — the skill tells Claude how to combine results from multiple agents into a coherent report.

> "Think of it like microservices: agents are the services — small, focused, independently
> deployable. Skills are the API gateway — routing, orchestration, the developer-facing
> interface. Both are markdown. Both are committed to the repo."

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

This resets to clean `origin/main`. The issues are permanently baked in — no re-injection needed.

**Do not push during a demo.** If you accidentally push fixed code to `origin/main`, the issue counts in the SessionStart hook will drop. Restore by re-pushing the original `main` state.

--------

## Appendix

See [DEMO_APPENDIX.md](DEMO_APPENDIX.md) — agent anatomy, skill/agent patterns, enterprise best practices, and the full inventory.
