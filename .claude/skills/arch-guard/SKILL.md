---
name: arch-guard
description: >
  Architecture compliance check using the architecture-analyzer agent.
  Triggered by: /arch-guard, "check architecture compliance", "are there any
  dependency violations", "check module boundaries".
tools:
  - Agent
---

# /arch-guard — Architecture Compliance Check

Spawns the `architecture-analyzer` agent to verify that the codebase's actual dependency structure complies with intended architectural constraints defined in SonarQube.

## Trigger

`/arch-guard`

## Architecture

```
/arch-guard (orchestrator)
    │
    └── architecture-analyzer agent
        ├── get_intended_architecture (constraints)
        ├── get_current_architecture (actual)
        ├── get_references (coupling points)
        └── get_downstream_call_flow (violation traces)
```

For this demo repository, a single `architecture-analyzer` agent checks all modules. In larger codebases, the orchestrator can fan out one agent per top-level module for parallel analysis.

## Steps

### Step 1 — Launch architecture-analyzer agent

Use the Agent tool to spawn an `architecture-analyzer` agent. Include in the prompt:
- The project key from CLAUDE.md
- Instruction to check all modules and report the full compliance matrix

### Step 2 — Present results

Relay the agent's compliance report to the user.

If no constraints are defined (empty `get_intended_architecture`), the agent will recommend constraints based on observed patterns. Frame this positively:

> "No architecture constraints are configured yet. The agent analyzed the current structure and recommends these boundaries. You can define them in SonarQube Cloud to enforce them automatically."

## Prerequisite

For the full compliance demo, architecture constraints should be configured in SonarQube Cloud for this project. Without them, the skill demonstrates **constraint recommendation** — still a valuable demo showing what the architecture tools can discover.
