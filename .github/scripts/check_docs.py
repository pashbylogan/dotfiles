#!/usr/bin/env python3
"""Docs-integrity checker for the omarchy-dotfiles knowledge base. [D-CI]"""

import json
import os
import re
import sys
from glob import glob

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = os.path.join(REPO, "docs")
REGISTRY = os.path.join(DOCS, "registry.json")

# Registry ids look like D-ENGINE / F-TMUX-XDG. Match them only when they are an
# HTML anchor (id="..."), so prose/href mentions don't count as anchors.
ID_RE = re.compile(r'id="((?:D|F)-[A-Z0-9-]+)"')
HREF_RE = re.compile(r'href="([^"]+)"')

# Guard repo-relative stale paths only; home-path mentions like ~/.tmux.conf can
# still be legitimate when documenting platform behavior.
STALE_TOKENS = {
    "brew-update": {"todos.html"},
    "tmux/.tmux.conf": set(),
}

problems = []


def bad(msg):
    problems.append(msg)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def has_token(body, token):
    """Whole-token containment: `token` not glued to an id-character on either
    side. Prevents a short id (D-BASE) from matching inside a longer one
    (D-BASELINE), and a stale token from matching inside a larger word
    (brew-update vs brew-update-all)."""
    return re.search(r"(?<![0-9A-Za-z-])" + re.escape(token) + r"(?![0-9A-Za-z-])", body) is not None


def main():
    html_files = sorted(glob(os.path.join(DOCS, "*.html")))
    if not html_files:
        bad(f"no docs/*.html found under {DOCS} - wrong directory?")
        return finish()
    html = {os.path.basename(f): read(f) for f in html_files}

    # Include README because registry appears_in can reference it.
    text = dict(html)
    readme = os.path.join(REPO, "README.md")
    if os.path.exists(readme):
        text["README.md"] = read(readme)

    try:
        reg = json.loads(read(REGISTRY))
    except FileNotFoundError:
        bad(f"registry.json not found at {os.path.relpath(REGISTRY, REPO)}")
        return finish()
    except json.JSONDecodeError as exc:
        bad(f"registry.json is not valid JSON: {exc}")
        return finish()

    entries = reg.get("decisions", []) + reg.get("findings", [])
    for n, e in enumerate(entries):
        if not isinstance(e, dict) or "id" not in e:
            bad(f"registry entry #{n} is not an object with an 'id' field")
    if problems:
        return finish()
    ids = {e["id"] for e in entries}

    for e in entries:
        eid, canon = e["id"], e.get("canonical", "")
        fname, _, anchor = canon.partition("#")
        if fname not in html:
            bad(f"{eid}: canonical file '{fname}' is not a docs page")
        elif not anchor:
            bad(f"{eid}: canonical '{canon}' has no #anchor")
        elif f'id="{anchor}"' not in html[fname]:
            bad(f"{eid}: anchor #{anchor} missing in {fname}")

    anchors = set()
    for body in html.values():
        anchors |= set(ID_RE.findall(body))
    for a in sorted(anchors - ids):
        bad(f'HTML anchor id="{a}" has no registry entry')
    for i in sorted(ids - anchors):
        bad(f"registry id {i} has no HTML anchor")

    # File code_paths must cite their ids so docs can be traced with grep.
    for e in entries:
        for p in e.get("code_paths", []):
            full = os.path.join(REPO, p)
            if not os.path.exists(full):
                bad(f"{e['id']}: code_path '{p}' does not exist")
            elif os.path.isfile(full) and f"[{e['id']}]" not in read(full):
                bad(f"{e['id']}: code_path '{p}' is missing its [{e['id']}] token")

    for e in entries:
        for r in e.get("related", []):
            if r not in ids:
                bad(f"{e['id']}: related id '{r}' is unknown")

    trace = html.get("traceability.html", "")
    for i in sorted(ids):
        if not has_token(trace, i):
            bad(f"{i} is missing from traceability.html")

    for fname, body in html.items():
        for href in HREF_RE.findall(body):
            if href.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target, _, frag = href.partition("#")
            if not target:
                continue
            if not os.path.exists(os.path.join(DOCS, target)):
                bad(f'{fname}: link href="{href}" -> missing {target}')
            elif frag and target.endswith(".html") and f'id="{frag}"' not in html.get(target, ""):
                bad(f'{fname}: link href="{href}" -> #{frag} not found in {target}')

    pages = set(html)
    index = html.get("index.html", "")
    for p in sorted(pages - {"index.html"}):
        if f'href="{p}"' not in index:
            bad(f"index.html does not link to page {p}")
    for fname, body in html.items():
        for other in sorted(pages - {fname}):
            if f'href="{other}"' not in body:
                bad(f"{fname}: topnav is missing a link to {other}")

    # Exclude traceability and canonical pages because they mention ids by design.
    sources = {k: v for k, v in text.items() if k != "traceability.html"}
    for e in entries:
        eid = e["id"]
        canon_file = e.get("canonical", "").split("#")[0]
        want = sorted(label for label, body in sources.items() if has_token(body, eid) and label != canon_file)
        have = sorted(e.get("appears_in", []))
        if want != have:
            bad(f"{eid}: appears_in is stale - stored {have}, should be {want}")

    for token, allowed in STALE_TOKENS.items():
        for label, body in text.items():
            if has_token(body, token) and label not in allowed:
                where = ", ".join(sorted(allowed)) or "nowhere"
                bad(f"stale token '{token}' in {label} (only allowed in: {where})")

    return finish(len(reg.get("decisions", [])), len(reg.get("findings", [])))


def finish(n_dec=0, n_find=0):
    if problems:
        print(f"docs-integrity: {len(problems)} problem(s):\n")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"docs-integrity: OK - {n_dec} decisions + {n_find} findings, all checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
