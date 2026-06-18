---
name: personalize
description: >
  Generates a customer-tailored demo flow by reading the repo's demo guides (DEMO_GUIDE.md =
  full, WORKSHOP_GUIDE.md = lite, WORKSHOP_GUIDE_SQS.md = Server), selecting beats by
  complexity × platform, pulling customer context from Glean (if available) or the SE directly,
  validating prompts live via claude -p in a worktree, and writing a ready-to-run demo-flows.md.
  Source of truth is always the repo guides — no separate library to maintain.
triggers:
  - /personalize
  - /personalize <customer-name>
  - personalize the demo for <customer>
tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
  - mcp__glean_portkey-glean__search
  - mcp__glean_portkey-glean__read_document
  - mcp__glean_portkey-glean__meeting_lookup
  - mcp__glean_portkey-glean__gmail_search
---

# /personalize — Customer-Tailored Demo Flow Generator

Reads the repo's existing demo guides (the proven source of truth), pulls customer context from
Glean, validates prompts in a fresh session, and writes a focused 1-pager an SE can use live.

No separate beat library to maintain. Everything flows from the three guides:
- **`DEMO_GUIDE.md`** — full, high-maturity (Cloud); every beat tagged with a `Requires:` marker
- **`WORKSHOP_GUIDE.md`** — lite, prompts-only (Cloud)
- **`WORKSHOP_GUIDE_SQS.md`** — Server / on-prem variant

Step 5 picks which to draw from based on complexity × platform.

---

## Track → Maturity Reference (internal — do not surface to user)

| Track | When to Use |
|---|---|
| **A — Guardrails & Gates** | Any maturity. Security/compliance pain. Show hooks, CLAUDE.md, SessionStart context, before/after gate. |
| **B — AI-Assisted Dev** | Piloting AI coding tools (Copilot, Cursor, Claude). Inner loop story. Guide→Generate→Verify. |
| **C — Autonomous Agents** | Scaling AI. Team-level governance concern. `/sonar-blitz`, `/tech-debt-sprint`, `/arch-guard`. |
| **D — Custom Agent Patterns** | Platform/advanced. Building on top of Sonar. `/security-posture`, `/sonar-onboard`, `/instance-report`. |

**Simplified mode** (prompts only, no infrastructure explanation) — use when:
- Exec/CTO-only, no engineer on the call
- First call or SDR-set scope-and-probe
- Session < 20 min
- No AI tooling in their current stack

In simplified mode: show the prompt, show the output. Do not explain hooks, CLAUDE.md, or skill anatomy.

---

## Step 1 — Resolve Customer Name

Extract from args (e.g., `/personalize Payoneer` → `Payoneer`). If no name was provided, ask.
Customer folder: `~/customers/<CustomerName>/`

---

## Step 2 — Pull Customer Context

Check local files first:
- `~/customers/<CustomerName>/callprep.md`
- `~/customers/<CustomerName>/account-brief.md`

**If Glean is connected**, use it to fill gaps:
- `gmail_search`: query `"<CustomerName>"`, after 2 weeks ago
- `meeting_lookup`: query `"<CustomerName>"`, after 4 weeks ago
- `search`: query `"<CustomerName> AI code quality pain tooling"`

**If Glean is not available**, skip directly to Step 3 — the AskUserQuestion prompts
cover everything Glean would have provided.

Extract (do not surface raw results to user):
- **Personas on the call** — role/title
- **Primary pain or stated interest** — exact quotes if available
- **AI maturity** — exploring / piloting / scaling
- **Current tooling** — IDE, CI, code quality, AI coding tools
- **Platform** — SonarQube **Cloud** or **Server** (on-prem)? Default to Cloud unless
  on-prem / "Server" / "self-hosted" / "no Docker" signals appear.
- **Session type** — discovery, scope-and-probe, deep dive, demo
- **Session length** — if known

---

## Step 3 — Fill Gaps (max 3 AskUserQuestion calls)

Ask about everything not resolved by Step 2. Without Glean, all three questions may fire.
Batch as tightly as possible.

**Q1** (if personas or primary pain missing):
> "Who's on the call and what's the one thing they most want to see?
> (Role + their words if you have them — exact quotes anchor the framing best)"

**Q2** (if AI maturity or session length missing):
> "Two quick things: How mature is this team with AI coding tools?
> (exploring / piloting / scaling) — and how long is the session?"

**Q3** (if platform, tooling, or session type still unknown):
> "A few more details: Are they on SonarQube Cloud or Server (on-prem)?
> What's their current code quality / CI setup? And is this a discovery call,
> a deep-dive demo, or something else?"

If everything is resolved from local files or Glean, skip to Step 4.

---

## Step 4 — Capability Check (optional, Glean only)

**Skip this step if Glean is not connected.**

If Glean is available, search for recent Sonar AI capability updates:
- `search`: `"SonarQube AI capabilities new features 2026"`
- `search`: `"SQAA sonar verify update"`
- `search`: `"Sonar MCP announcement"`

Goal: ensure the recommended beats reflect the current product. Flag anything significantly
different from what the guides describe.

---

## Step 5 — Assess Complexity × Platform → Pick the Source Guide

Two independent axes from the customer profile (Steps 2-3) decide **which guide** you draw from:

**Complexity:**
- **Full story** — hooks, CLAUDE.md, skills, agents as infrastructure. The plumbing is part of the
  demo. Use for: engineers, architects, DevEx leads, AI governance stakeholders, longer sessions.
- **Simplified / lite** — prompts only. What does Claude do? What does SonarQube catch? No plumbing.
  Use for: execs, first calls, scope-and-probe, very short sessions, customers with no AI tooling.

**Platform:** Cloud or Server (on-prem).

| Platform | Complexity | Draw beats from |
|---|---|---|
| Cloud | Full | `DEMO_GUIDE.md` (any `Requires:` tag, including `skill:`/`agent:`) |
| Cloud | Lite | `WORKSHOP_GUIDE.md` — or DEMO_GUIDE beats tagged `none`/`hooks`/`mcp` only |
| Server | Either | `WORKSHOP_GUIDE_SQS.md` — avoid CAG/SQAA beats (Cloud only); prefer `sonar api` + standard MCP |

Record both decisions — they pick the guide in Step 6 and shape framing in Step 8.

---

## Step 6 — Read Source Docs & Select Beats

Read the guide(s) chosen in Step 5:
- `DEMO_GUIDE.md` — full track reference; every beat carries a `> **Requires:**` tag
  (`none` / `hooks` / `mcp` / `skill:<name>` / `agent:<name>`)
- `WORKSHOP_GUIDE.md` — lite, prompts-only Cloud workshop (maturity 1-2)
- `WORKSHOP_GUIDE_SQS.md` — Server variant (`sonar api`, no Docker, CAG/SQAA caveats)

Select 2-3 specific prompts or workflows from the right track. Rules:
- **Honor the `Requires:` tags.** For a **lite** demo, pick only beats tagged `none`/`hooks`/`mcp` —
  do not select `skill:`/`agent:` beats. For **Server**, never pick CAG (`get_guidelines`) or
  SQAA (`sonar verify`) beats — they're Cloud only.
- Match the track to AI maturity (Track A=any, B=piloting, C/D=scaling)
- Lead with the prompt/workflow most directly tied to their stated pain or a verbatim customer quote
- Prompts must be verbatim from the guide — no paraphrasing
- Never pick more than 3

---

## Step 7 — Validate Prompts in Worktree

For each selected prompt, test it in a fresh session:

```bash
# Create a worktree for clean testing
git worktree add .claude/worktrees/personalize-test main

# Test each prompt (run from repo root, worktree context)
cd .claude/worktrees/personalize-test
claude -p "<prompt verbatim from guide>"
```

Check:
- Does the output match what the guide describes?
- Does it trigger the right MCP tool calls?
- Is the output something an SE can point at and explain in < 30 seconds?

**If a prompt produces unexpected output or fails:**
1. Try the closest variant from the guide
2. Re-test the variant
3. If still unclear after 2 attempts, use `AskUserQuestion`:
   > "The prompt `<prompt>` isn't producing the expected output right now.
   > Here's what I got: `<summary>`. Want to try a variation, or should I swap in a
   > different prompt for this slot?"

Clean up the worktree after all prompts are validated.

---

## Step 8 — Write Output

Create `~/customers/<CustomerName>/demos/` if needed, then write `demo-flows.md`.

```markdown
# Demo Flow: <CustomerName>
**Prepared:** <date>
**Session:** <type> (~<N> min)
**Personas:** <role 1>, <role 2>
**AI maturity:** <exploring / piloting / scaling>
**Complexity:** <full / simplified>

---

## Beat 1: <Short Name> (~<N> min)

### Setup
<Pre-prompt steps if needed — verbatim from guide. Skip section if none.>

### Prompt
```
<Exact verbatim prompt — never paraphrase>
```

### What to Watch For
<3-5 bullets from the tested output. What should Claude call/do? What should appear?>

### How to Frame It
> "<1-2 sentences using their actual words or stack where possible. Generic framing as fallback.>"
> [Full story only] "<Follow-up line pointing at the enforcement mechanism — hook, gate, etc.>"

### Next
<One sentence on where to go if they're engaged — which beat follows naturally>

---

## Beat 2: <Short Name> (~<N> min)

[same structure]

---

## Pre-Call Checklist
- [ ] On `main` branch (not `demo/bad-state`)
- [ ] MCP server connected (sonarqube visible in sidebar)
- [ ] <beat-specific items — e.g. "useProjectMetrics.ts must NOT exist" for generate-verify>
- [ ] Test lead prompt in a fresh session the morning of the call
- [ ] <customer-specific prep note if relevant>

---

## If They Ask...

**"<Likely objection or question based on their stack/context>"**
<One sentence response.>

**"<Second likely question>"**
<One sentence response.>
```

**Output rules:**
- Prompts are verbatim — copied from what was validated in Step 7
- Customer language beats generic framing — use their words
- Don't reference competitor or third-party tools unless they appeared in the customer context

- Simplified mode: omit the "How to Frame It" infrastructure line; keep framing to the output, not the plumbing

---

## Terminal Summary

After writing the file, print:

```
Done. ~/customers/<CustomerName>/demos/demo-flows.md written.

Track: <A/B/C/D> (<complexity level>)
Prompts: <prompt 1 short name> → <prompt 2> [→ <prompt 3>]
Why: <one sentence — the primary signal that drove selection>
```
