# Customer Health Scorecard

A customer health tracking application for SonarQube SE demos.

## What It Does

Tracks health scores for SonarQube customer accounts by pulling quality gate status,
scan recency, and tier information from the SonarQube API. Scores are displayed on
a React dashboard with drill-down into individual accounts.

## Stack

| Layer | Tech |
|-------|------|
| Backend | Python 3.12 / FastAPI / SQLAlchemy / SQLite |
| Frontend | React 18 / TypeScript / Vite / Tailwind CSS |
| Quality | SonarQube Cloud (`sonar-solutions` org) |

## Quick Start

See [.claude/CLAUDE.md](.claude/CLAUDE.md) for full development instructions.

```bash
# Backend
cd backend && source .venv/bin/activate && uvicorn app.main:app --reload

# Frontend (separate terminal)
cd frontend && npm run dev
```

## SE Setup

### Prerequisites

- Python 3.12, Node.js 20+, Docker (running)
- SonarQube CLI: run `/plugin install sonarqube@sonar` in Claude Code, or download from [SonarSource docs](https://docs.sonarsource.com/sonarqube-cloud/advanced-setup/ci-based-analysis/sonarscanner-cli/)
- GitHub CLI: https://cli.github.com — run `gh auth login` after installing
- Claude Code

> `.venv` and `node_modules` are pre-committed — no `pip install` or `npm install` needed after cloning.

### Environment variables

One SonarQube Cloud user token covers all three. Generate one at sonarcloud.io → My Account → Security → Generate Token (needs Admin + Execute Analysis on the `sonar-solutions` org).

```bash
export SONAR_TOKEN=<your-token>            # sonar CLI auth
export SONARQUBE_CLOUD_TOKEN=<your-token>  # demo-reset.sh
export SONARCLOUD_DEMOS_TOKEN=<your-token> # MCP server
```

Add all three to `~/.zshrc` or `~/.bashrc` so they're set on every shell open.

### MCP setup

`.mcp.json` is included and uses `$(pwd)` for the workspace path — no manual path editing needed. Claude Code picks it up automatically when you open the repo.

If MCP shows `✗ not connected` in the session start output, run `/mcp` in Claude Code to diagnose.

### First demo run

```bash
bash scripts/demo-reset.sh
```

Open a fresh Claude Code session. The SessionStart hook should output issue counts, coverage/complexity measures, and `MCP: ✓ connected`. If everything looks good, you're demo-ready.

### Per-SE live-push branch

For the C4 architecture violation demo beat, create your own sandbox branch:

```bash
bash scripts/demo-reset.sh --se <yourname>
```

This creates `demo/live-push-<yourname>` scoped to you.

--------

## SonarQube Demo Coverage

This project demonstrates:

- **SCA (dual-language)** — Vulnerable deps in `requirements.txt` (`requests==2.18.4`) and `package.json` (`lodash@4.17.10`)
- **Security hotspots** — API token in query param (backend), token in localStorage (frontend)
- **Code smells** — High cognitive complexity in `backend/app/services/scoring.py`
- **Architecture analysis** — import-linter (Python) + dependency-cruiser (TypeScript) rules enforced in CI
- **Test aggregation** — Combined Python + TypeScript coverage in one quality gate
- **PR quality gate** — `demo/bad-state` branch has a PR open against `main` with a failing gate

## Demo Branches

| Branch | State |
|--------|-------|
| `main` | Issues present |
| `demo/bad-state` | PR open, quality gate failing |
| `demo/fixed-state` | Issues resolved, quality gate passing |
