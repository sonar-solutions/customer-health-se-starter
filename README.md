# Customer Health Scorecard

A demo application for SonarQube + Claude Code SE presentations. It's a realistic FastAPI + React
monorepo with intentional quality issues baked in — used to showcase the **AC/DC framework**
(Agent Centric Development Cycle: Guide → Generate → Verify → Solve) across four audience tracks.

## What This Demonstrates

| Track | Audience | Key Beats |
|-------|----------|-----------|
| **A: Guardrails** | Security-first, compliance-heavy | Session-start hook with live issue counts, CLAUDE.md as committed baseline, secrets scanning on every prompt and file read, SCA dependency check, `/pre-push-review` |
| **B: AI-Assisted Dev** | Teams using Copilot / Claude for generation | `get_guidelines` (project-specific rules), guided code generation, PostToolUse auto-verify hook, `/sonar-fix` |
| **C: Autonomous Agents** | Teams scaling agentic workflows | `/sonar-blitz` (parallel fix agents), `/tech-debt-sprint` (two-wave), `/arch-guard`, live push triggering CI quality gate failure |
| **D: Custom Agent Patterns** | Platform engineering | `/security-posture` (3-agent), `/sonar-onboard`, agent anatomy walkthrough, `/instance-report` (existing customers) |

See [DEMO_GUIDE.md](DEMO_GUIDE.md) for the full script, track timings, and Q&A prep.

## Stack

| Layer | Tech |
|-------|------|
| Backend | Python 3.12 / FastAPI / SQLAlchemy / SQLite |
| Frontend | React 18 / TypeScript / Vite / Tailwind CSS |
| Quality | SonarQube Cloud (`sonar-solutions` org) |

---

## Setup

### Prerequisites

- Python 3.12, Node.js 20+, Docker (running)
- [Claude Code](https://claude.ai/code)
- GitHub CLI: https://cli.github.com — run `gh auth login` after installing
- SonarQube CLI — run `/plugin install sonarqube@sonar` inside Claude Code
- A SonarCloud account with an organization you can create projects in

> `.venv` and `node_modules` are pre-committed — no `pip install` or `npm install` needed.

### Create your own SonarCloud project (run this first)

Each SE manages their own PRs, so each needs their **own** SonarCloud project. The setup script
creates it, points the repo at it, and tells you which env vars to export:

```bash
bash scripts/setup.sh --org <your-sonarcloud-org> --name "Customer Health Scorecard"
```

It validates your token, creates the project (idempotent — reuses if it exists), writes the key +
org into `sonar-project.properties` (the single source of truth every hook and script reads), and
prints the `export` block below. Generate a token first at sonarcloud.io → My Account → Security →
Generate Token (needs **Create Projects + Execute Analysis** on your org).

### Environment variables

`setup.sh` prints these filled in — add them to `~/.zshrc` or `~/.bashrc`:

```bash
export SONAR_TOKEN=<your-token>          # one token used by sonar CLI, MCP server, and demo-reset.sh
export SONARQUBE_ORG=<your-org>          # MCP server + hooks
export SONARQUBE_PROJECT_KEY=<your-key>  # MCP server + hooks
# export SONARQUBE_URL=<url>             # only if not using sonarcloud.io (e.g. staging)
```

### MCP setup

`.mcp.json` is committed and reads your org + project key from the `SONARQUBE_ORG` /
`SONARQUBE_PROJECT_KEY` env vars (set above), and mounts the repo via `$(pwd)` — no path editing
needed. Claude Code picks it up automatically when you open the repo.

If MCP shows `✗ not connected` at session start, confirm those env vars are exported in your
shell, then run `/mcp` inside Claude Code to diagnose.

### Start the app

```bash
# Backend
cd backend && source .venv/bin/activate && uvicorn app.main:app --reload
# → http://localhost:8000  (API docs at /docs)

# Frontend (separate terminal)
cd frontend && npm run dev
# → http://localhost:5173
```

### First demo run

```bash
bash scripts/demo-reset.sh
```

Open a fresh Claude Code session. The SessionStart hook outputs live issue counts, coverage/complexity measures, and `MCP: ✓ connected`. If all three appear, you're demo-ready.

### Personal copy (no fork access)

If you don't have fork access to the `sonar-solutions` org, create your own independent **git** copy
and keep it synced. (After cloning your copy, run `bash scripts/setup.sh` above to point it at your
own SonarCloud project.)

**One-time setup:**

```bash
# 1. Create a new empty repo on your GitHub account first (no README, no .gitignore)

# 2. Bare-clone and mirror-push
git clone --bare https://github.com/sonar-solutions/customer-health.git
cd customer-health.git
git push --mirror https://github.com/<you>/customer-health.git
cd .. && rm -rf customer-health.git

# 3. Clone your copy and register the original as upstream
git clone https://github.com/<you>/customer-health.git
cd customer-health
git remote add upstream https://github.com/sonar-solutions/customer-health.git
```

**Periodic sync** (pull updates from the original into your copy):

```bash
git fetch upstream
git rebase upstream/main
git push origin main
```

Your copy is fully independent — you can demo freely without touching the shared repo.

### Toggle demo skills and agents

Between demos (or when doing non-demo work in this repo), you can disable all SonarQube demo-specific skills and agents in one command:

```bash
bash scripts/demo-mode.sh
```

Run it again to re-enable. Moves agents between `.claude/agents/` and `.claude/agents.disabled/`, and updates `skillOverrides` in `.claude/settings.local.json`. Restart Claude Code after toggling. Does not affect `/personalize`.

### Per-SE live-push branch

Required for the Track C architecture-violation beat (C4). Creates a sandbox branch scoped to you:

```bash
bash scripts/demo-reset.sh --se <yourname>
```

This creates `demo/live-push-<yourname>` and wires up the PR.

---

## Baked-in Issues

| Category | Detail |
|----------|--------|
| **SCA — Python** | `requests==2.18.4` in `requirements.txt` (CVE-2018-18074, SSRF, HIGH) |
| **SCA — JS** | `lodash@4.17.10` in `package.json` (CVE-2019-10744, HIGH) |
| **Security hotspot** | API token passed as query param (backend) |
| **Security hotspot** | Token stored in `localStorage` (frontend) |
| **Code smell** | High cognitive complexity in `backend/app/services/scoring.py` |
| **Arch violation** | `services/` layer imports from `api/` layer (Python); `services/` imports from component layer (TypeScript) |
| **Coverage gap** | Combined Python + TypeScript coverage surfaces gaps in quality gate |
| **Failing PR gate** | `demo/bad-state` has an open PR against `main` with a failing quality gate |

## Demo Branches

| Branch | State |
|--------|-------|
| `main` | Issues present, quality gate data available |
| `demo/bad-state` | PR open, quality gate failing |
| `demo/fixed-state` | Issues resolved, quality gate passing |
| `demo/live-push-<name>` | Per-SE sandbox for live-fix beats (Track C4) |

## Related Docs

| File | Purpose |
|------|---------|
| [DEMO_GUIDE.md](DEMO_GUIDE.md) | Full demo script — framing, track beats, Q&A prep, troubleshooting, agent anatomy |
| [WORKSHOP_GUIDE.md](WORKSHOP_GUIDE.md) | Lite facilitator guide — prompts-only, no custom skills required (Cloud) |
| [WORKSHOP_GUIDE_SQS.md](WORKSHOP_GUIDE_SQS.md) | Server-variant workshop — `sonar api`, no Docker, CAG/SQAA caveats |
| [.claude/CLAUDE.md](.claude/CLAUDE.md) | Development reference — architecture rules, tooling, MCP tools |
| [scripts/setup.sh](scripts/setup.sh) | One-time SE setup — creates your SonarCloud project, sets config |
| [scripts/demo-mode.sh](scripts/demo-mode.sh) | Toggle demo skills/agents on or off between sessions |
