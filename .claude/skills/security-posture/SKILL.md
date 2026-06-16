---
name: security-posture
description: >
  Full security assessment using three specialized agents in a two-wave orchestration.
  Maps attack surface, inventories vulnerabilities, and traces reachability.
  Triggered by: /security-posture, "security assessment", "what's exploitable",
  "OWASP analysis", "pen test the codebase", "trace the attack chains".
tools:
  - Agent
---

# /security-posture — Security Assessment

The most advanced skill in this repo. Uses a two-wave, three-agent orchestration pattern to produce an OWASP Top 10-mapped security assessment with reachability analysis.

## Trigger

`/security-posture`

## Architecture

```
/security-posture (orchestrator)
    │
    ├── WAVE 1 (parallel)
    │   ├── attack-surface-mapper agent    ── all public endpoints
    │   └── vulnerability-correlator agent ── all vulns + CWE mappings
    │
    ├── WAVE 2 (sequential, uses Wave 1 results)
    │   └── data-flow-tracer agent         ── reachability from endpoints to vulns
    │
    └── Synthesize into OWASP-mapped risk report
```

## Steps

### Step 1 — Wave 1: Map surface and inventory vulnerabilities (parallel)

Launch two agents **in parallel** using a single message with multiple Agent tool calls:

1. **attack-surface-mapper agent** — find all public endpoints (FastAPI routes, React pages)
2. **vulnerability-correlator agent** — inventory all open vulnerabilities and security hotspots with OWASP/CWE categorization

### Step 2 — Wave 2: Trace reachability (sequential)

Once Wave 1 completes, launch the **data-flow-tracer agent** with:
- The endpoint inventory from attack-surface-mapper (public entry points and their method FQNs)
- The vulnerability inventory from vulnerability-correlator (vulnerable methods with their FQNs)

The tracer will determine which vulnerabilities are structurally reachable from public endpoints.

### Step 3 — Synthesize OWASP Report

Combine all three agent reports into a unified security assessment:

```
SECURITY POSTURE REPORT
========================
Project: <project-key>

ATTACK SURFACE
  Total public endpoints: <N>
  <endpoint list from attack-surface-mapper>

OWASP TOP 10 COVERAGE
  A01 Broken Access Control:     <N> findings
  A02 Cryptographic Failures:    <N> findings
  A03 Injection:                 <N> findings
  A08 Software Integrity:        <N> findings
  ...
  (omit categories with 0 findings)

REACHABILITY ANALYSIS
  REACHABLE (highest priority — connected to public endpoint):
    [1] <file>:<line> — <rule> — <OWASP category>
        Chain: <endpoint> -> ... -> <vulnerable method>

  INDIRECT (connected but sanitization detected):
    [1] <file>:<line> — <rule>
        Sanitizer: <method or pattern>

  UNREACHABLE (no public entry path):
    [1] <file>:<line> — <rule>

RISK SUMMARY
  Critical (REACHABLE + BLOCKER/CRITICAL): <N>
  Elevated (REACHABLE + MAJOR or INDIRECT + BLOCKER): <N>
  Low (UNREACHABLE or MINOR): <N>

RECOMMENDED REMEDIATION
  Priority 1 (REACHABLE BLOCKERs):
    /sonar-fix <issue-key> — <description>
  Priority 2 (REACHABLE CRITICALs):
    /sonar-fix <issue-key> — <description>
  Priority 3 (INDIRECT):
    Review manually — sanitization may be sufficient
```

## Error Handling

- If attack-surface-mapper fails, skip Wave 2 and report vulnerability inventory only
- If vulnerability-correlator fails, skip Wave 2 and report attack surface only
- If data-flow-tracer fails, report Wave 1 findings without reachability classification
- Always produce a report with whatever data is available

## Note

Reachability analysis is **structural** (call-graph based), not full taint analysis. A "REACHABLE" classification means the call graph connects endpoint to vulnerability — it does not guarantee runtime exploitability. This is clearly stated in the report.
