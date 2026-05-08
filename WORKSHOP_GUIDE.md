# SonarQube in AI-Assisted Development — Workshop Outline

**Format:** Facilitator-led · **Duration:** ~45 min · **Project:** sonar-solutions_Health-Dashboard

**Audience:** Teams in AC/DC maturity levels 1 & 2 with familiarity with SQ

> **TODO:** more definition around who this workshop is for

**Before starting:** `bash scripts/demo-reset.sh` · Open fresh Claude Code session · Confirm MCP connection

**Fork:** https://github.com/sonar-solutions/Health-Dashboard

---

## 0 — Framing *(5 min)*

- The problem: AI increases code volume *and* rework simultaneously. 37% of AI PRs fail quality gates.
- The three outcomes, in order of effort: **Verify → Guide → Solve**
- (Verify will be a more realistic and valuable starting point for most orgs than Guide)
- Potentially add slide to frame for SQ analysis as a baseline

---

## 1 — The Building Blocks *(5 min, no demo)*

Name the components before they appear live.

- **CLI** (`sonar`) — Runs analysis on files, detects secrets. Deterministic. Runs anywhere a shell runs.
- **MCP server** — Exposes SonarQube data to Claude as callable tools. Live analysis, not training data.
- **Maybe align on commonalities between common AI tools** (these concepts exist across all tools)
- **Skills vs Hooks + CLAUDE.md** — Wires CLI and MCP into the workflow automatically. Deterministic enforcement, not AI discretion.

---

## 2 — CLI: The Foundation *(8 min)*

- **Run:**
  ```bash
  sonar verify --file backend/app/clients/sonarqube_client.py --project sonar-solutions_Health-Dashboard
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
- **Point out:** Watch the tool calls — Claude made several MCP calls autonomously because it saw the quality gate was failing and kept digging. Everything in that output came from SonarQube analysis, not from reading the source files.
- CLI vs MCP callout

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

**Point out:** `get_guidelines` → edit → `sonar verify`. Show the clean result.

**Run:** `/sonar-fix`

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
