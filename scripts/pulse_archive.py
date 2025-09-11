
#!/usr/bin/env python3
"""
Revised Archive Pulse

What it does
------------
Reads a configuration Excel (default: archive_pulse.xlsx) whose *columns* are
hub (Archive) seed target URLs and whose *rows* are the constellation seed URLs
to aggregate for each target. For each column, it fetches the YAML files listed
in the cells, concatenates them, de-duplicates by "key" when available (falls
back to whole-object), and writes the merged YAML to the Archive repository path
indicated by the column header URL (the path after `/tree/<branch>/`).

Optionally, if HUB_PAT/HUB_OWNER/HUB_REPO are provided, pushes the updated files
via the GitHub Contents API.

Environment
-----------
- HUB_PAT   : (required to push) classic/repo-scoped PAT for the hub repo
- HUB_OWNER : e.g., "zbreeden"
- HUB_REPO  : e.g., "fourtwentyanalytics" or "archive-model" (your Archive repo)
- HUB_BRANCH: branch to write against (default: "main")
- XLSX_PATH : path to the Excel config (default: "./archive_pulse.xlsx")
- DRY_RUN   : if "1", only writes to local filesystem (no API push)

Dependencies
------------
- requests
- pyyaml
- pandas (for reading the Excel)
"""

import base64
import json
import os
import re
import sys
from typing import Any, Dict, Iterable, List, Optional, Tuple, Union

try:
    import requests
except Exception as e:
    print("[pulse] Missing dependency: requests", file=sys.stderr)
    raise

try:
    import yaml
except Exception as e:
    print("[pulse] Missing dependency: pyyaml", file=sys.stderr)
    raise

try:
    import pandas as pd
except Exception as e:
    print("[pulse] Missing dependency: pandas", file=sys.stderr)
    raise


def log(msg: str) -> None:
    print(f"[pulse] {msg}")


def to_raw_url(tree_url: str) -> Optional[str]:
    """Convert a GitHub tree URL to a raw URL.
    Accepts forms like:
      https://github.com/<owner>/<repo>/tree/<branch>/<path>
    Returns:
      https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>
    """
    if not tree_url or not isinstance(tree_url, str):
        return None
    m = re.match(r"^https://github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.+)$", tree_url.strip())
    if not m:
        return None
    owner, repo, branch, path = m.groups()
    return f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}"


def hub_path_from_url(tree_url: str) -> Optional[Tuple[str, str, str]]:
    """Return (owner, repo, path) for the hub target from a tree URL"""
    m = re.match(r"^https://github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.+)$", tree_url.strip())
    if not m:
        return None
    owner, repo, branch, path = m.groups()
    return owner, repo, path


def gh_headers(token: Optional[str]) -> Dict[str, str]:
    h = {"Accept": "application/vnd.github+json", "User-Agent": "archive-pulse/1.0"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h


def fetch_yaml(url: str) -> List[Dict[str, Any]]:
    """Fetch YAML from raw URL and normalize to a list of dicts."""
    r = requests.get(url, timeout=30)
    if r.status_code != 200:
        raise RuntimeError(f"GET {url} -> {r.status_code}")
    text = r.text
    data = yaml.safe_load(text) if text.strip() else []
    # Normalize:
    if data is None:
        return []
    if isinstance(data, list):
        # ensure list of dicts when possible
        return [x if isinstance(x, dict) else {"value": x} for x in data]
    if isinstance(data, dict):
        # convert mapping -> list of {key: k, **v} if values are dicts
        out = []
        for k, v in data.items():
            if isinstance(v, dict):
                d = dict(v)
                d.setdefault("key", k)
                out.append(d)
            else:
                out.append({"key": k, "value": v})
        return out
    # fallback: wrap as value
    return [{"value": data}]


def dedupe_records(records: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """De-dupe by 'key' when present, otherwise by JSON-ser of the object."""
    seen_key = set()
    seen_blob = set()
    out: List[Dict[str, Any]] = []
    for rec in records:
        if not isinstance(rec, dict):
            rec = {"value": rec}
        if "key" in rec and isinstance(rec["key"], str) and rec["key"]:
            k = rec["key"]
            if k in seen_key:
                continue
            seen_key.add(k)
            out.append(rec)
        else:
            blob = json.dumps(rec, sort_keys=True, ensure_ascii=False)
            if blob in seen_blob:
                continue
            seen_blob.add(blob)
            out.append(rec)
    return out


def write_yaml_local(path: str, records: List[Dict[str, Any]]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(records, f, allow_unicode=True, sort_keys=False)
    log(f"wrote {path} ({len(records)} rows)")


def gh_get_content_sha(owner: str, repo: str, path: str, branch: str, token: str) -> Optional[str]:
    url = f"https://api.github.com/repos/{owner}/{repo}/contents/{path}"
    r = requests.get(url, headers=gh_headers(token), params={"ref": branch}, timeout=30)
    if r.status_code == 200:
        return r.json().get("sha")
    if r.status_code == 404:
        return None
    raise RuntimeError(f"GET {url} -> {r.status_code} {r.text[:200]}")


def gh_put_file(owner: str, repo: str, path: str, branch: str, token: str, content_bytes: bytes, message: str) -> None:
    url = f"https://api.github.com/repos/{owner}/{repo}/contents/{path}"
    sha = gh_get_content_sha(owner, repo, path, branch, token)
    payload = {
        "message": message,
        "content": base64.b64encode(content_bytes).decode("ascii"),
        "branch": branch,
    }
    if sha:
        payload["sha"] = sha
    r = requests.put(url, headers=gh_headers(token), json=payload, timeout=30)
    if r.status_code not in (200, 201):
        raise RuntimeError(f"PUT {url} -> {r.status_code} {r.text[:400]}")
    log(f"pushed {owner}/{repo}@{branch}:{path}")


def parse_excel(xlsx_path: str) -> List[Tuple[str, List[str]]]:
    """
    Returns a list of tuples: (hub_target_tree_url, [source_tree_urls...])
    The Excel is expected to have one sheet. Each column header is the hub target URL.
    Each non-empty cell under a column is a source repo tree URL to aggregate.
    """
    df = pd.read_excel(xlsx_path, sheet_name=0)
    # Drop fully empty columns
    df = df.dropna(axis=1, how="all")
    results: List[Tuple[str, List[str]]] = []
    for col in df.columns:
        hub_url = str(col).strip()
        # Collect non-empty cell values in this column
        srcs = []
        for val in df[col].tolist():
            if isinstance(val, float) and pd.isna(val):
                continue
            if val is None:
                continue
            s = str(val).strip()
            if not s or s.lower() == "nan":
                continue
            srcs.append(s)
        results.append((hub_url, srcs))
    return results


def main() -> int:
    xlsx_path = os.getenv("XLSX_PATH", "archive_pulse.xlsx")
    dry_run = os.getenv("DRY_RUN", "").strip() == "1"
    hub_pat = os.getenv("HUB_PAT", "").strip()
    hub_owner = os.getenv("HUB_OWNER", "").strip()
    hub_repo  = os.getenv("HUB_REPO", "").strip()
    hub_branch = os.getenv("HUB_BRANCH", "main").strip()

    if not os.path.exists(xlsx_path):
        raise SystemExit(f"Config Excel not found at {xlsx_path}")

    plan = parse_excel(xlsx_path)
    if not plan:
        raise SystemExit("No columns/targets found in Excel.")

    # Process each target column independently
    pushes: List[Tuple[str, str]] = []  # (repo, path) pushed
    for hub_tree_url, src_tree_urls in plan:
        # Determine hub local path (relative to the hub repo root) and also verify owner/repo match if provided
        hub_tuple = hub_path_from_url(hub_tree_url)
        if not hub_tuple:
            log(f"skip invalid hub URL: {hub_tree_url}")
            continue
        hub_owner_from_col, hub_repo_from_col, hub_rel_path = hub_tuple

        # Warn if XLS specifies different hub repo than environment (we still honor env for push)
        if hub_owner and hub_repo and (hub_owner_from_col != hub_owner or hub_repo_from_col != hub_repo):
            log(f"warning: hub URL owner/repo ({hub_owner_from_col}/{hub_repo_from_col}) "
                f"differs from HUB_OWNER/HUB_REPO ({hub_owner}/{hub_repo}).")

        # Fetch all source YAMLs
        merged: List[Dict[str, Any]] = []
        for src_tree_url in src_tree_urls:
            raw = to_raw_url(src_tree_url)
            if not raw:
                log(f"  skip invalid source URL: {src_tree_url}")
                continue
            try:
                rows = fetch_yaml(raw)
                log(f"  + {src_tree_url} -> {len(rows)} rows")
                merged.extend(rows)
            except Exception as e:
                log(f"  ! error fetching {src_tree_url}: {e}")
                continue

        # De-dupe
        merged = dedupe_records(merged)

        # Write locally (assuming script is run at repo root of hub)
        local_path = hub_rel_path  # same relative path as in URL
        write_yaml_local(local_path, merged)

        # Optionally push
        if not dry_run and hub_pat and hub_owner and hub_repo:
            try:
                with open(local_path, "rb") as f:
                    content_bytes = f.read()
                gh_put_file(hub_owner, hub_repo, hub_rel_path, hub_branch, hub_pat, content_bytes,
                            message=f"archive pulse: update {hub_rel_path} ({len(merged)} rows)")
                pushes.append((hub_repo, hub_rel_path))
            except Exception as e:
                log(f"  ! push failed for {local_path}: {e}")

    if pushes:
        log("completed pushes:\n  " + "\n  ".join([f"{r}:{p}" for r, p in pushes]))
    else:
        log("completed (local writes only)")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print("[pulse] FATAL:", repr(e), file=sys.stderr)
        sys.exit(1)
