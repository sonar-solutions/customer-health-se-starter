import json, sys, subprocess, os, re

# Read project key from CLAUDE.md
project = None
claude_md = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "CLAUDE.md")
try:
    with open(claude_md) as f:
        for line in f:
            m = re.search(r'\*\*SonarQube project key:\*\*\s*`([^`]+)`', line)
            if m:
                project = m.group(1)
                break
except Exception:
    pass

if not project:
    print(json.dumps({"systemMessage": "SonarQube session-start: could not find project key in CLAUDE.md"}))
    sys.exit(0)

sonar = "sonar"
env = dict(os.environ)

def get_issues(severity, n=5):
    try:
        r = subprocess.run(
            [sonar, "list", "issues", "-p", project, "--format", "json", "--page-size", str(n), "--severity", severity],
            capture_output=True, text=True, env=env, timeout=30
        )
        return json.loads(r.stdout)
    except Exception:
        return {"total": 0, "issues": []}

blockers = get_issues("BLOCKER")
criticals = get_issues("CRITICAL")

lines = []
for i in (blockers.get("issues", []) + criticals.get("issues", []))[:5]:
    f = i["component"].split(":")[-1].split("/")[-1]
    l = i.get("textRange", {}).get("startLine", "?")
    sev = i["severity"]
    msg = i["message"]
    lines.append("  [{}] {}:{} - {}".format(sev, f, l, msg))

top = "\n".join(lines)
summary = (
    "SonarQube context loaded | {}\n"
    "{} BLOCKER, {} CRITICAL open issues\n\n"
    "Top issues:\n{}\n\n"
    "Per CLAUDE.md: consult SonarQube MCP before editing any file."
).format(project, blockers["total"], criticals["total"], top)

print(json.dumps({"systemMessage": summary}))
