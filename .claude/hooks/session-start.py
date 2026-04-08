import json, subprocess, os, re, sys

# --- project key ---
project = None
repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
try:
    with open(os.path.join(repo_root, "sonar-project.properties")) as f:
        for line in f:
            m = re.match(r'sonar\.projectKey\s*=\s*(.+)', line.strip())
            if m:
                project = m.group(1).strip()
                break
except Exception:
    pass

if not project:
    sys.exit(0)

env = dict(os.environ)

# --- git branch ---
branch = None
try:
    r = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"],
                       capture_output=True, text=True, timeout=5, cwd=repo_root)
    branch = r.stdout.strip() or None
except Exception:
    pass

# --- open PR ---
pr_number = None
pr_label = None
try:
    r = subprocess.run(
        ["gh", "pr", "view", "--json", "number,title,state"],
        capture_output=True, text=True, timeout=10, cwd=repo_root,
        env={**env, "GITHUB_TOKEN": ""}
    )
    if r.returncode == 0:
        pr = json.loads(r.stdout)
        if pr.get("state") == "OPEN":
            pr_number = str(pr["number"])
            pr_label = f"PR #{pr_number}: {pr['title']}"
except Exception:
    pass

# --- fetch issues via CLI ---
def get_issues(severity, n=500):
    cmd = ["sonar", "list", "issues", "-p", project,
           "--format", "json", "--page-size", str(n), "--severity", severity]
    if pr_number:
        cmd += ["--pull-request", pr_number]
    elif branch:
        cmd += ["--branch", branch]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=30)
        return json.loads(r.stdout)
    except Exception:
        return {"total": 0, "issues": []}

blockers = get_issues("BLOCKER")
criticals = get_issues("CRITICAL")
majors = get_issues("MAJOR")

# --- format output ---
header_parts = [project]
if branch:
    header_parts.append(branch)
if pr_label:
    header_parts.append(pr_label)

lines = ["SonarQube | " + " | ".join(header_parts)]
lines.append("")
lines.append("Open issues:")
lines.append(f"  BLOCKER:  {blockers['total']}")
lines.append(f"  CRITICAL: {criticals['total']}")
lines.append(f"  MAJOR:    {majors['total']}")

top = (blockers.get("issues", []) + criticals.get("issues", []))[:5]
if top:
    lines.append("")
    lines.append("Top issues:")
    for i in top:
        f = i["component"].split(":")[-1].split("/")[-1]
        l = i.get("textRange", {}).get("startLine", "?")
        sev = i["severity"]
        msg = i["message"]
        lines.append(f"  [{sev}] {f}:{l} — {msg}")

lines.append("")
lines.append("Per CLAUDE.md: consult SonarQube MCP before editing any file.")

print(json.dumps({"systemMessage": "\n".join(lines)}))
