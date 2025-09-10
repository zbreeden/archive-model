#!/usr/bin/env python3
import argparse, os, sys, requests, yaml
from urllib.parse import quote

def load_yaml(p):
    with open(p, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def fetch_raw(owner, repo, path, branch="main"):
    url = f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{quote(path)}"
    r = requests.get(url, timeout=20)
    if r.status_code == 200:
        return r.text
    return None

def ensure_dir(p):
    os.makedirs(p, exist_ok=True)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--registry", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--schemas-dir", required=True)
    args = ap.parse_args()

    registry = load_yaml(args.registry)
    # Expect registry like:
    # modules:
    #   - owner: zbreeden
    #     repo: launch-model
    #   - owner: zbreeden
    #     repo: archive-model
    modules = registry.get("modules", [])

    ensure_dir(args.out_dir)

    seeds_to_pull = ["glossary.yml", "tags.yml"]  # extend as needed

    for m in modules:
        owner = m["owner"]
        repo  = m["repo"]
        for seed in seeds_to_pull:
            text = fetch_raw(owner, repo, f"seeds/{seed}")
            if not text:
                continue
            # write into hub structure
            ensure_dir(os.path.join(args.out_dir))
            outp = os.path.join(args.out_dir, seed)
            with open(outp, "w", encoding="utf-8") as f:
                f.write(text)

    print("Harvest complete.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
