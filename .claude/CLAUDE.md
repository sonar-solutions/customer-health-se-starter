# Customer Health Scorecard — Claude Code Guide

## Project Overview
FE/BE monorepo: FastAPI backend (Python) + React/TypeScript frontend.
Demo project for SonarQube SE demos — intentional issues are present in `main` branch.

## Running the Backend

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload
```

API available at http://localhost:8000. Docs at http://localhost:8000/docs.

## Running the Frontend

```bash
cd frontend
npm run dev
```

UI available at http://localhost:5173.

## Testing

### Backend
```bash
cd backend && source .venv/bin/activate
pytest tests/ -v --cov=app --cov-report=term-missing --cov-report=xml
```

### Frontend
```bash
cd frontend
npx vitest run --coverage
```

## Architecture Checks

### Backend (import-linter)
```bash
cd backend && source .venv/bin/activate
lint-imports
```

### Frontend (dependency-cruiser)
```bash
cd frontend
npx depcruise src --config .dependency-cruiser.js
```

## Local SonarQube Scan
```bash
sonar-scanner \
  -Dsonar.projectKey=customer-health-scorecard \
  -Dsonar.token=$SONAR_TOKEN
```

## Architecture Rules
- Backend: `api` → `services` → `repositories`/`clients` → `models`/`schemas`
- Frontend: `pages` → `components`, `hooks`, `services` (no reverse imports)
- Violations fail CI

## Intentional Issues (for SonarQube Demo)
These are baked in on purpose — do NOT fix them on `main`:

| Issue | File | Type |
|-------|------|------|
| Token in query param | `backend/app/clients/sonarqube_client.py` | Security Hotspot |
| High cognitive complexity | `backend/app/services/scoring.py` | Code Smell |
| Token in localStorage | `frontend/src/services/api.ts` | Security Hotspot |
| Missing error state | `frontend/src/hooks/useHealthScore.ts` | Bug |
| `requests==2.18.4` | `backend/requirements.txt` | SCA (CVE-2018-18074) |
| `lodash@4.17.10` | `frontend/package.json` | SCA (CVE-2019-10744) |

## Demo Branches
- `demo/bad-state` — issues present, quality gate failing (use for "before" demo)
- `demo/fixed-state` — issues resolved, quality gate passing (use for "after" demo)

## Branch Naming
- Features: `feat/<description>`
- Demo scenarios: `demo/<scenario-name>`
