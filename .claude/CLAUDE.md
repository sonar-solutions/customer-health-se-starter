# Customer Health Scorecard — Claude Code Guide

## Project Info
- **SonarQube project key:** `sonar-solutions_Health-Dashboard`
- **SonarQube org:** `sonar-solutions`
- **MCP server:** sonarqube (available in this session)

## Project Overview
FE/BE monorepo: FastAPI backend (Python) + React/TypeScript frontend.
Demo project for the SonarQube MCP + CLI tool suite — intentional issues are present in `main` branch.

## Mandatory SonarQube Workflow

### Before editing any file
1. Call `get_guidelines` with `mode: "project_based"` — get rules derived from this project's issue history
2. Call `show_rule` on any CRITICAL or BLOCKER rules before touching related code

### After writing or modifying a file
1. Call `run_advanced_code_analysis` with the file content — real-time CI-quality analysis
2. Treat any new findings as blocking — fix before moving on

### Before any commit
1. Call `get_project_quality_gate_status` to confirm the gate is still passing

### Before changing architecture
1. Call `get_current_architecture` to understand the structure
2. Call `get_intended_architecture` to check constraints
3. Use `get_upstream_call_flow` / `get_downstream_call_flow` to trace impact

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
npx depcruise src --config .dependency-cruiser.cjs
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

## Demo Branches
- `demo/bad-state` — issues present, quality gate failing (use for "before" demo)
- `demo/fixed-state` — issues resolved, quality gate passing (use for "after" demo)

## Branch Naming
- Features: `feat/<description>`
- Demo scenarios: `demo/<scenario-name>`

## Agent Building Blocks (.claude/agents/)

| Agent | Purpose | Key Tools |
|-------|---------|-----------|
| `attack-surface-mapper` | Find public endpoints and entry points | `search_by_signature_patterns`, `get_current_architecture` |
| `vulnerability-correlator` | Inventory vulns + hotspots with CWE | `search_sonar_issues_in_projects`, `show_rule` |
| `data-flow-tracer` | Trace call-path reachability | `get_upstream/downstream_call_flow` |
| `architecture-analyzer` | Check module compliance against constraints | `get_current/intended_architecture`, `get_references` |
| `blast-radius-tracer` | Map upstream callers and dependency impact | `get_upstream_call_flow`, `get_references` |
| `issue-fixer` | Fix a single issue with full AC/DC loop | `get_guidelines`, `run_advanced_code_analysis` |
| `health-analyzer` | Overall project health summary | `get_component_measures`, `get_project_quality_gate_status` |

## Available SonarQube MCP Tools

### Context Augmentation (CAG)
- `get_guidelines` — project-specific coding rules filtered to your task and files
- `get_current_architecture` — hierarchical architecture graph of this codebase
- `get_intended_architecture` — user-defined architectural constraints
- `get_upstream_call_flow` — trace what calls a given method
- `get_downstream_call_flow` — trace what a method calls
- `get_references` — inbound and outbound code dependencies
- `search_by_signature_patterns` — find code by method/class signatures
- `search_by_body_patterns` — find code by implementation patterns
- `get_source_code` — get complete source by fully qualified name

### Agentic Analysis
- `run_advanced_code_analysis` — real-time CI-quality analysis on a file (use after every edit)

### Standard Tools
- `search_sonar_issues_in_projects` — list open issues
- `get_project_quality_gate_status` — check quality gate status
- `show_rule` — full remediation guidance for a rule
- `search_security_hotspots` — security hotspots
- `get_component_measures` — coverage, complexity, duplication metrics
