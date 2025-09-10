#!/usr/bin/env python3
"""
pulse_archive.py
- Scans your constellation (optionally via GitHub topic), or just this repo.
- Writes:
    archive/signals/modules_index.json
    archive/signals/pulse_badge.json
    archive/signals/signal_beacon.json
- Optionally patches README.md between HEALTH markers.

Requires: requests, pyyaml
Env:
  GITHUB_TOKEN       (auto in Actions)
  FOURTWENTY_TOPIC   (optional; enables topic-based discovery)
"""

from __future__ import annotations
import json
import os
import sys
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml  # type: ignore
except Exception:
    yaml = None

try:
    import requests  # type: ignore
except Exception:
    requests = None

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_DIR = ROOT / "signals"
INDEX_OUT = ARCHIVE_DIR / "modules_index.json"
BADGE_OUT = ARCHIVE_DIR / "pulse_badge.json"
BEACON_OUT = ARCHIVE_DIR / "signal_beacon.json"
README = ROOT / "README.md"

HEALTH_START = "<!-- ARCHIVE:HEALTH:START -->"
HEALTH_END = "<!-- ARCHIVE:HEALTH:END -->"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def mkdirs() -> None:
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)


def gh_headers() -> Dict[str, str]:
    tok = os.getenv("GITHUB_TOKEN")
    h = {"Accept": "application/vnd.github+json"}
    if tok:
        h["Authorization"] = f"Bearer {tok}"
    return h


def gh_get(url: str, params: Optional[Dict[str, Any]] = None) -> Any:
    if requests is None:
        raise RuntimeError("requests not installed but needed for GitHub API calls")
    r = requests.get(url, headers=gh_headers(), params=params, timeout=30)
    r.raise_for_status()
    return r.json()


def discover_repos_via_topic() -> List[Dict[str, Any]]:
    """Return minimal info for repos that match the topic and owner."""
    topic = os.getenv("FOURTWENTY_TOPIC")
    repo_env = os.getenv("GITHUB_REPOSITORY", "")
    owner = repo_env.split("/")[0] if "/" in repo_env else os.getenv("GITHUB_REPOSITORY_OWNER", "")
    if not topic or not owner:
        return []

    repos: List[Dict[str, Any]] = []
    page = 1
    while True:
        url = f"https://api.github.com/search/repositories"
        q = f"topic:{topic} user:{owner}"
        payload = gh_get(url, {"q": q, "per_page": 100, "page": page})
        items = payload.get("items", [])
        for it in items:
            repos.append({
                "key": it["name"].replace("-", "_"),
                "name": it["name"],
                "repo": it["html_url"],
                "default_branch": it.get("default_branch"),
                "last_push": it.get("pushed_at"),
                "stars": it.get("stargazers_count"),
                "archived": it.get("archived"),
            })
        if len(items) < 100:
            break
        page += 1
    return repos


def read_local_seeds() -> Dict[str, bool]:
    seeds = {
        "modules": (ROOT / "seeds" / "modules.yml").exists(),
        "tags": (ROOT / "seeds" / "tags.yml").exists(),
        "glossary": (ROOT / "seeds" / "glossary.yml").exists(),
        "rules": (ROOT / "seeds" / "rules.yml").exists(),
    }
    return seeds


def load_registry_yaml() -> List[Dict[str, Any]]:
    """
    Optional: if seeds/registry.yml exists, load module entries from it.
    Expected (flexible) shape: list of {key, repo, orbit?, status?}
    """
    reg = ROOT / "seeds" / "registry.yml"
    if not reg.exists() or yaml is None:
        return []
    try:
        data = yaml.safe_load(reg.read_text()) or []
        if isinstance(data, list):
            return [d for d in data if isinstance(d, dict)]
    except Exception:
        pass
    return []


def compose_local_repo_row() -> Dict[str, Any]:
    """Produce a row for *this* repo so you always have at least one entry."""
    repo_env = os.getenv("GITHUB_REPOSITORY", "")
    html = f"https://github.com/{repo_env}" if repo_env else ""
    seeds = read_local_seeds()
    return {
        "key": (repo_env.split("/")[-1] if repo_env else "this_repo").replace("-", "_"),
        "name": repo_env.split("/")[-1] if repo_env else "this_repo",
        "repo": html,
        "orbit": "core",
        "status": "active",
        "last_push": None,   # could be filled via API if desired
        "seeds": seeds,
        "checks": {
            "schemas_ok": True,           # placeholder; wire up real validation later
            "readme_backlink": True,      # placeholder
        },
    }


def build_modules_index() -> List[Dict[str, Any]]:
    """
    Priority:
      1) If registry.yml exists → use it as the spine.
      2) Else if FOURTWENTY_TOPIC set → search GitHub.
      3) Always include a row for this repo.
    """
    index: List[Dict[str, Any]] = []

    reg_rows = load_registry_yaml()
    if reg_rows:
        for r in reg_rows:
            row = {
                "key": r.get("key") or (r.get("name") or "unknown").replace("-", "_"),
                "name": r.get("name") or r.get("key") or "unknown",
                "repo": r.get("repo") or "",
                "orbit": r.get("orbit") or "unknown",
                "status": r.get("status") or "unknown",
                "last_push": r.get("last_push"),
                "seeds": r.get("seeds") or {},
                "checks": r.get("checks") or {},
            }
            index.append(row)

    if not index:
        # try topic discovery
        topic_rows = []
        try:
            topic_rows = discover_repos_via_topic()
        except Exception as e:
            print(f"[pulse] topic discovery skipped: {e}")
        for tr in topic_rows:
            index.append({
                "key": tr["key"],
                "name": tr["name"],
                "repo": tr["repo"],
                "orbit": "unknown",
                "status": "unknown",
                "last_push": tr.get("last_push"),
                "seeds": {},
                "checks": {},
            })

    # Always include this repo (de-dup by key)
    this_row = compose_local_repo_row()
    if not any(r.get("key") == this_row["key"] for r in index):
        index.append(this_row)

    # Sort by name for stable diffs
    index.sort(key=lambda r: r.get("name", ""))
    return index


def write_json(path: Path, obj: Any) -> None:
    path.write_text(json.dumps(obj, indent=2))
    print(f"[pulse] wrote {path.relative_to(ROOT)}")


def write_artifacts(index_rows: List[Dict[str, Any]]) -> None:
    mkdirs()
    # 1) modules_index
    write_json(INDEX_OUT, index_rows)

    # 2) badge (tiny)
    badge = {
        "status": "ok",
        "timestamp": utc_now_iso(),
        "modules": len(index_rows),
        "healthy": sum(1 for r in index_rows if r.get("checks", {}).get("schemas_ok") is True),
        "warnings": sum(1 for r in index_rows if r.get("checks", {}).get("schemas_ok") is False),
    }
    write_json(BADGE_OUT, badge)

    # 3) signal beacon (change tick)
    beacon = {"latest": [{"type": "modules_index_refresh", "at": utc_now_iso(), "changed": 0}]}
    write_json(BEACON_OUT, beacon)


def render_health_table(index_rows: List[Dict[str, Any]]) -> str:
    """Simple markdown table for README panel."""
    lines = [
        "### System Health",
        "",
        "| Module | Orbit | Status | Seeds (m/t/g) | Last Push |",
        "|---|---|---|---|---|",
    ]
    for r in index_rows:
        seeds = r.get("seeds", {})
        seed_str = f"{'✅' if seeds.get('modules') else '—'}/" \
                   f"{'✅' if seeds.get('tags') else '—'}/" \
                   f"{'✅' if seeds.get('glossary') else '—'}"
        lines.append(f"| [{r.get('name')}]({r.get('repo','')}) "
                     f"| {r.get('orbit','—')} | {r.get('status','—')} "
                     f"| {seed_str} | {r.get('last_push') or '—'} |")
    return "\n".join(lines) + "\n"


def patch_readme_panel(index_rows: List[Dict[str, Any]]) -> None:
    """Insert/replace the HEALTH section in README using on-disk index."""
    if not README.exists():
        print("[pulse] README.md not found; skipping health panel patch.")
        return

    content = README.read_text()
    panel = "\n".join([HEALTH_START, "", render_health_table(index_rows), HEALTH_END]) + "\n"

    if HEALTH_START in content and HEALTH_END in content:
        # replace existing block
        pattern = re.compile(
            re.escape(HEALTH_START) + r".*?" + re.escape(HEALTH_END),
            flags=re.DOTALL,
        )
        new = pattern.sub(panel, content)
    else:
        # append to end
        new = content.rstrip() + "\n\n" + panel

    if new != content:
        README.write_text(new)
        print("[pulse] README.md health panel updated.")
    else:
        print("[pulse] README.md health panel unchanged.")


def main() -> int:
    rows = build_modules_index()
    write_artifacts(rows)
    # Read back what we wrote (single source of truth) for README patch
    try:
        idx_rows = json.loads(INDEX_OUT.read_text())
    except Exception:
        idx_rows = rows  # fallback if read fails
    patch_readme_panel(idx_rows)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print("[pulse] FATAL:", repr(e), file=sys.stderr)
        sys.exit(1)
