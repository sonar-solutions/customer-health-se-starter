# AC/DC Demo — Appendix

Reference material for the [Demo Guide](DEMO_GUIDE.md). Agent anatomy, skill/agent patterns, enterprise best practices, and the full inventory.

--------

## How This Is Built

### Agent Anatomy

```yaml
# .claude/agents/issue-fixer.md
---
name: issue-fixer
description: Fixes a single SonarQube issue with full AC/DC loop.
tools:
  - mcp__sonarqube__get_guidelines
  - mcp__sonarqube__show_rule
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

### When to Use Which Pattern

| Pattern | Example | When to use |
|---------|---------|-------------|
| **Skill (inline)** | `/sonar-audit`, `/pre-push-review` | Simple workflows — sequential MCP calls, no need for isolation or parallelism |
| **Skill → 1 agent** | `/sonar-fix`, `/arch-guard` | Need tool restrictions or context isolation |
| **Skill → N agents** | `/security-posture`, `/sonar-blitz` | Multi-specialist workflows — parallel execution, wave orchestration, result synthesis |

```
Is the workflow simple (< 5 sequential steps, no parallelism)?
  YES → Inline skill (e.g., /sonar-audit, /pre-push-review)
  NO  → Does it need tool restrictions or context isolation?
    YES → Skill → agent delegation (e.g., /sonar-fix → issue-fixer)
    NO  → Does it need multiple specialists or parallel execution?
      YES → Skill → N agents with wave orchestration (e.g., /security-posture)
      NO  → Inline skill is fine
```

**Why skills delegate to agents:**
1. **Tool restrictions** — agents are sandboxed to their capabilities (`attack-surface-mapper` can only search/read; `issue-fixer` can edit and run bash)
2. **Context isolation** — each agent gets a fresh context window, keeping intermediate results out of the main conversation
3. **Parallelism** — agents run concurrently (wave 1: attack-surface-mapper + vulnerability-correlator; wave 2: data-flow-tracer)

**Why skills exist on top of agents:**
1. **Orchestration** — skills compose single-responsibility agents into multi-step workflows with wave ordering
2. **Discoverability** — `/security-posture` shows up in tab-completion; agents don't
3. **Synthesis** — the skill tells Claude how to combine results from multiple agents into a coherent report

> "Think of it like microservices: agents are the services — small, focused, independently
> deployable. Skills are the API gateway — routing, orchestration, the developer-facing
> interface. Both are markdown. Both are committed to the repo."

**Rule of thumb:** Skills are the developer-facing interface. Agents are the execution units. Simple workflows don't need agents. Complex workflows shouldn't run inline.

--------

## Enterprise Best Practices

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

## Agent & Skill Reference

### Agents (.claude/agents/)

| Agent | Purpose | Key Tools |
|-------|---------|-----------|
| `attack-surface-mapper` | Map public FastAPI routes and React page entries | `search_by_signature_patterns`, `get_current_architecture` |
| `vulnerability-correlator` | Inventory vulns + SCA risks + hotspots with CWE | `search_sonar_issues_in_projects`, `search_dependency_risks`, `show_rule` |
| `data-flow-tracer` | Trace call-path reachability | `get_upstream/downstream_call_flow` |
| `health-analyzer` | Comprehensive health: metrics, coverage, duplication, issue concentration | `get_component_measures`, `get_project_quality_gate_status` |
| `metrics-analyzer` | Lightweight metrics dashboard | `get_component_measures`, `get_project_quality_gate_status` |
| `debt-hotspot-finder` | Top files by bug/code-smell density | `search_sonar_issues_in_projects`, `get_source_code` |
| `blast-radius-tracer` | Map upstream callers and dependency impact | `get_upstream_call_flow`, `get_references` |
| `architecture-analyzer` | Check module compliance against constraints | `get_current/intended_architecture`, `get_references` |
| `issue-fixer` | Fix a single issue with full AC/DC loop | `get_guidelines`, `show_rule`, `sonar verify` (CLI), `Read`, `Edit` |

### Skills

| Skill | Tier | AC/DC | Agents | Pattern |
|-------|------|-------|--------|---------|
| `/sonar-fix` | AI-Assisted | G+G+V | `issue-fixer` | Single delegation |
| `/pre-push-review` | Guardrails | V | (none) | Direct CLI calls |
| `/sonar-audit` | Guardrails | G+V | (none) | Flat skill |
| `/sonar-blitz` | Autonomous | All | `issue-fixer` x N | Parallel fan-out |
| `/arch-guard` | Autonomous | G+V | `architecture-analyzer` | Single delegation |
| `/tech-debt-sprint` | Autonomous | G | `metrics-analyzer` + `debt-hotspot-finder` -> `blast-radius-tracer` | Two-wave |
| `/security-posture` | Custom Agent | All | `attack-surface-mapper` + `vulnerability-correlator` -> `data-flow-tracer` | Two-wave |
| `/sonar-onboard` | Autonomous | G | `architecture-analyzer` + `health-analyzer` + `debt-hotspot-finder` | Parallel fan-out |
