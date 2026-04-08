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
