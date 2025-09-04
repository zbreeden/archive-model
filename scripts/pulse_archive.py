import os, json, requests, yaml, datetime, sys
from pathlib import Path

ARCHIVE_ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ARCHIVE_ROOT / "seeds" / "registry.yml"
INDEX_OUT = ARCHIVE_ROOT / "archive" / "modules_index.json"

GITHUB_API = "https://api.github.com"
SESSION = requests.Session()
SESSION.headers.update({"Authorization": f"Bearer {os.environ.get('GITHUB_TOKEN','')}",
                       "Accept": "application/vnd.github+json"})

REQUIRED_STATUS_KEYS = ["id","label","emoji","order","meaning","criteria","allowed_next"]

def load_registry():
    if REGISTRY.exists():
        data = yaml.safe_load(REGISTRY.read_text())
        return [(r["owner"], r["name"]) for r in data.get("repos", [])]
    # fallback: topic discovery (optional)
    topic = os.environ.get("FOURTWENTY_TOPIC", "")
    if not topic:
        return []
    q = f"topic:{topic} archived:false"
    repos = []
    page = 1
    while True:
        r = SESSION.get(f"{GITHUB_API}/search/repositories",
                        params={"q": q, "per_page": 100, "page": page})
        r.raise_for_status()
        items = r.json().get("items", [])
        if not items: break
        repos += [(it["owner"]["login"], it["name"]) for it in items]
        page += 1
    return repos

def get_default_branch(owner, repo):
    r = SESSION.get(f"{GITHUB_API}/repos/{owner}/{repo}")
    if r.status_code != 200:
        return None
    return r.json().get("default_branch")

def fetch_raw(owner, repo, branch, path):
    url = f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}"
    rr = SESSION.get(url)
    return rr.text if rr.status_code == 200 else None

def validate_statuses(statuses, where):
    problems = []
    for i, item in enumerate(statuses):
        missing = [k for k in REQUIRED_STATUS_KEYS if k not in item]
        if missing:
            problems.append(f"{where} status[{i}] missing: {missing}")
        if "criteria" in item and not isinstance(item["criteria"], (list, tuple)):
            problems.append(f"{where} status[{i}] criteria must be a list")
        if "allowed_next" in item and not isinstance(item["allowed_next"], (list, tuple)):
            problems.append(f"{where} status[{i}] allowed_next must be a list")
    return problems

def main():
    repos = load_registry()
    summary = []
    issues = []

    for owner, repo in repos:
        branch = get_default_branch(owner, repo)
        if not branch:
            issues.append(f"{owner}/{repo}: cannot read default branch")
            continue

        seeds_to_pull = ["seeds/statuses.yml", "seeds/glossary.yml", "seeds/tags.yml"]
        pulled = {}
        for path in seeds_to_pull:
            txt = fetch_raw(owner, repo, branch, path)
            if txt:
                try:
                    pulled[path] = yaml.safe_load(txt)
                except Exception as e:
                    issues.append(f"{owner}/{repo}: YAML parse error in {path}: {e!s}")

        statuses = pulled.get("seeds/statuses.yml") or []
        if statuses and isinstance(statuses, dict) and "items" in statuses:
            # allow either a list or a keyed structure
            statuses = statuses["items"]

        if statuses:
            problems = validate_statuses(statuses, f"{owner}/{repo}")
            issues.extend(problems)

        # Basic module facts for the index
        mod = {
            "repo": f"{owner}/{repo}",
            "branch": branch,
            "seeds_found": list(pulled.keys()),
            "counts": {
                "statuses": len(statuses) if isinstance(statuses, list) else 0,
                "glossary": len(pulled.get("seeds/glossary.yml", []) or []),
                "tags":     len(pulled.get("seeds/tags.yml", []) or []),
            },
            "sample_status_ids": [s.get("id") for s in statuses][:5] if isinstance(statuses, list) else [],
            "last_pulsed_utc": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z",
        }
        summary.append(mod)

    INDEX_OUT.parent.mkdir(parents=True, exist_ok=True)
    old = {}
    if INDEX_OUT.exists():
        try:
            old = json.loads(INDEX_OUT.read_text())
        except Exception:
            pass

    out = {"modules": summary}
    if out != old:
        INDEX_OUT.write_text(json.dumps(out, indent=2))

    # Optionally print issues to fail the run or just log them
    if issues:
        print("Pulse warnings/errors:")
        for line in issues:
            print(" -", line)
        # Non-fatal: comment out next line if you prefer soft warnings
        # sys.exit(1)

if __name__ == "__main__":
    main()

# Write modules index for README + dashboard
from pathlib import Path
import json

INDEX_OUT = Path("archive/modules_index.json")
INDEX_OUT.parent.mkdir(parents=True, exist_ok=True)

out = {"modules": summary}
old = {}
if INDEX_OUT.exists():
    try: old = json.loads(INDEX_OUT.read_text())
    except Exception: pass

if out != old:
    INDEX_OUT.write_text(json.dumps(out, indent=2))
    print(f"Wrote {INDEX_OUT}")

# Update README.md health table between markers
import datetime, re

def render_health_table(mods):
    def row(m):
        repo = m["repo"]
        seeds = ", ".join(Path(s).name for s in m.get("seeds_found", [])) or "—"
        c = m.get("counts", {})
        return f"| `{repo}` | `{m.get('branch','')}` | {c.get('statuses',0)} | {c.get('glossary',0)} | {c.get('tags',0)} | {seeds} | {m.get('last_pulsed_utc','—')} |"
    if not mods:
        body = "| (no modules indexed) |\n|---|\n"
    else:
        header = "| Repo | Branch | Statuses | Glossary | Tags | Seeds Found | Last Pulsed |\n|---|---:|---:|---:|---:|---|---|\n"
        body = header + "\n".join(row(m) for m in mods)
    return body

def patch_readme_table(index_json):
    readme_path = Path("README.md")
    if not readme_path.exists(): return
    md = readme_path.read_text()

    start = "<!-- HEALTH:START -->"
    end   = "<!-- HEALTH:END -->"
    if start not in md or end not in md: return

    table = render_health_table(index_json.get("modules", []))
    new_md = re.sub(
        f"{re.escape(start)}.*?{re.escape(end)}",
        f"{start}\n{table}\n{end}",
        md, flags=re.DOTALL
    )

    stamp = datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z"
    new_md = re.sub(r"<!-- HEALTH:STAMP -->.*?<!-- HEALTH:STAMP -->",
                    f"<!-- HEALTH:STAMP -->{stamp}<!-- HEALTH:STAMP -->",
                    new_md)

    if new_md != md:
        readme_path.write_text(new_md)
        print("README.md health section updated.")

# call this after writing modules_index.json
try:
    idx = json.loads(Path("archive/modules_index.json").read_text())
    patch_readme_table(idx)
except Exception as e:
    print("README health patch skipped:", e)

