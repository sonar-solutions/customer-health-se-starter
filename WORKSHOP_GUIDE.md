# SonarQube in AI-Assisted Development — Workshop Guide (Lite)

**Format:** Facilitator-led · **Duration:** ~45 min · **Complexity:** Lite — prompts and built-in tools only, no custom skills or agents required

**Audience:** Teams exploring or piloting AI coding tools (AC/DC maturity 1–2). Works for any SonarQube Cloud audience regardless of current AI tooling.

> **Using this guide:**
> - **High agentic maturity / full demo?** Use [DEMO_GUIDE.md](DEMO_GUIDE.md) — full infrastructure, all tracks, agent anatomy.
> - **SonarQube Server (on-prem) audience?** Use [WORKSHOP_GUIDE_SQS.md](WORKSHOP_GUIDE_SQS.md) — no Docker, `sonar api`, Server-specific framing.
> - **Personalizing for a customer?** Run `/personalize <customer>` — it reads all three guides.

**Before starting:** `bash scripts/demo-reset.sh` · Open fresh Claude Code session · Confirm MCP connection

**Repo:** if you don't have fork access to the shared project, follow [personal copy setup](README.md#personal-copy-no-fork-access) then run `bash scripts/setup.sh` to create your own SonarCloud project.

---

## 0 — Framing *(3 min)*

- The problem: AI increases code volume *and* rework simultaneously. 37% of AI PRs fail quality gates.
- The three outcomes, in order of effort: **Verify → Guide → Solve**

---

## 1 — The Building Blocks *(7 min, no demo)*

Name and show the components before they appear live. Audiences follow the demo better when they've seen the map first.

- **CLI** (`sonar`) — Runs analysis on individual files, detects secrets in prompts and staged files. Deterministic, runs anywhere a shell runs.
- **MCP server** — Exposes SonarQube data to the agent as callable tools. Three groups:
  - *CAG (Context Augmentation)* — `get_guidelines`, `get_current_architecture`, call-flow tools. Injects project-specific rules and structure before the agent writes anything.
  - *Agentic Analysis* — `sonar verify` via CLI. Real-time CI-quality analysis per file, triggered automatically by hooks.
  - *Standard* — `search_sonar_issues`, `get_project_quality_gate_status`, `get_component_measures`. What you'd normally click through in the UI, now callable in-session.
  - **Open** `.claude/CLAUDE.md` → "Available SonarQube MCP Tools" section. Let the audience read the tool names — they'll recognize them when they appear in the demo.
- **Hooks + CLAUDE.md** — Wires CLI and MCP tools into the workflow automatically. Deterministic enforcement, not AI discretion.

> **Two execution contexts — one integration:**
> - CLI = any shell, any IDE, any CI pipeline. No agent required.
> - MCP tools = Claude Code session (and now also hookable within it via `mcp_tool` hooks). Richer data, requires the server to be connected.
>
> Both run deterministically when wired through hooks. The difference is *where* they can run. This is why the CLI isn't redundant — it's what enforces quality standards everywhere the MCP server isn't present.

---

## 2 — CLI: The Foundation *(8 min)*

- **Run:**
  ```bash
  sonar verify --file backend/app/clients/sonarqube_client.py --project $SONARQUBE_PROJECT_KEY
  ```
- **Point out:** Hardcoded credential on line 10, token passed as query param on line 19. Output is structured: rule, line, severity.
- **Run** (paste into Claude Code prompt):
  > "Can you check my last PR run? My Github token is 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"
- **Point out:** The `UserPromptSubmit` hook intercepts the message before it reaches the model and blocks it. Same detection engine as CI — running on every prompt, automatically.

---

## 3 — MCP: What the Agent Can See *(7 min)*

- **Point out:** SessionStart hook fires on open — live issue counts injected as context before the first message.
- **Run:**
  > "Can you triage the issues in new code in this project?"
- **Point out:** Watch the tool calls — Claude made several MCP calls autonomously because it saw the quality gate was failing and kept digging. Everything in that output came from SonarQube analysis, not from reading the source files. Call back to Section 1: *"Those are the Standard tools — same data you'd find in the UI, now callable mid-session."*

---

## 4 — The Workflow: All Three Together *(20 min)*

> *Guardrails analogies for objections around "why not just trust AI generation directly? It's getting really good!"*

### Guide

**Run:** *"Pull the current coding guidelines for this project."*

**Point out:** `get_guidelines` via MCP — rules derived from *this project's* issue history. Note the rule: "Exceptions should not be ignored."

**Open** `frontend/src/hooks/useHealthScore.ts` line 15 — show `} catch (e) {}`. The silent failure pattern.

**Run:** *"Add a useProjectMetrics hook in frontend/src/hooks/ that fetches from metricsApi.get(accountId) and exposes metrics, loading, and error state."*

**Point out:** Error handled in state, not swallowed. Ask the audience: which building block did that? *(MCP — guidelines were in context before generation.)*

### Verify — hooks made it automatic

**Open** `.claude/settings.json` → show `PostToolUse` → `Edit|Write` → `sonar verify`

**Point out:** `sonar verify` already ran — the `PostToolUse` hook fired the moment Claude wrote the file. The CLI from §2, wired in by this config. No one invoked it.

**Say:** *"Developer can't skip it. AI can't skip it. It runs because the hook forces it — not because Claude decided to check its work."*

### Solve — inner loop

**Run:** *"Fix the highest-severity open issue in this project."*

**Point out:** `get_guidelines` → edit → `sonar verify`. Show the clean result. *(This is the lite beat — pure prompt, no custom skill.)*

**Run (optional — only if the team has adopted skills):** `/sonar-fix`

**Say:** *"Same loop, packaged as a single command. This is a markdown file in `.claude/skills/` committed to the repo. The SonarQube Remediation Agent is this same pattern running natively on PRs — without a developer in the loop."*

**Say:** *"Same loop, packaged. Now let me show you what it looks like when that loop runs without a developer in it at all."*

### Solve — outer loop (Remediation Agent — if time and tech allow)

**Open** the open PR on `demo/bad-state` in SonarQube Cloud.

**Run:** Check the Remediation Agent checkbox on the PR — show it triggering.

**Point out:** Same Guide → Verify → Solve loop, now running autonomously on the PR. No developer invoked it — the PR opening was the trigger.

**Jump to** SonarQube Cloud → show bulk assignment — how to assign multiple open issues to the Remediation Agent at once for a tech debt sweep.

**Show** the automation/scheduled maintenance config — how to set SQRA to run on a cadence so the main branch stays clean without anyone asking.

**Say:** *"Three modes: fix on PR, fix in bulk, fix on a schedule. The workflow is the same — what changes is who triggers it."*

---

## 5 — Wrap-up *(5 min)*

**Recap:**

- CLI = deterministic analysis anywhere
- MCP = live SonarQube data available to the agent
- Hooks = automatic enforcement, not AI discretion

**Adoption path:** Start with Verify → add Guide → package Solve when the team is ready.

**Governance:** Every step produces an artifact. The quality gate is the system of record.

**To get started:**

```
/plugin marketplace add SonarSource/sonarqube-agent-plugins
/plugin install sonarqube@sonar
```

---

## Open questions on commercials

- Context augmentation — billable?
- Agentic analysis — billable?
- Can you have one without the other?
- Will it be one enterprise package? (Remediation Agent?)
- How does cloud fit in? Architecture on server? SQAA for server?

Knowing the commercials will shape this workshop and what emphasis we put on different parts.
