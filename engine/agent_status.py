#!/usr/bin/env python3
"""
agent_status.py — detect installed AI agents & session counts, driven by
agents.json (the single source of truth shared with distribute.py and the
desktop apps).

The macOS app implements this detection natively in Swift
(AgentDetector.swift); the Windows app calls THIS script with --json and just
renders the result. CLI users get a quick status table for free:

    python3 agent_status.py            # human-readable table
    python3 agent_status.py --json     # machine-readable, for app frontends

READ-ONLY BY DESIGN: counts *.jsonl files and opens SQLite databases in
read-only mode; never writes to any agent's storage.

Per-platform paths: an agent entry in agents.json may carry an optional
"windows" block whose keys shallow-override the base (macOS) values when
running on Windows. Base "~/..." paths work everywhere via expanduser.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from typing import Any, Dict, List
from urllib.parse import quote

REGISTRY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "agents.json")


def platform_key() -> str:
    if sys.platform.startswith("win"):
        return "windows"
    if sys.platform == "darwin":
        return "darwin"
    return "linux"


def load_agents() -> List[Dict[str, Any]]:
    with open(REGISTRY, encoding="utf-8") as fh:
        reg = json.load(fh)
    key = platform_key()
    out = []
    for agent in reg.get("agents", []):
        override = agent.get(key)
        if isinstance(override, dict):
            merged = dict(agent)
            merged.update(override)
            out.append(merged)
        else:
            out.append(agent)
    return out


def _expand(path: str) -> str:
    return os.path.expanduser(path)


def _count_jsonl(dirs: List[str]) -> int:
    """Recursively count *.jsonl files (approximate session count)."""
    n = 0
    for d in dirs:
        base = _expand(d)
        if not os.path.isdir(base):
            continue
        for _root, _dirs, files in os.walk(base):
            n += sum(1 for f in files if f.endswith(".jsonl"))
    return n


def _sqlite_count(db: str, query: str) -> int:
    """Read-only COUNT query; returns 0 on any failure, never writes."""
    path = _expand(db)
    if not os.path.exists(path):
        return 0
    uri_path = quote(os.path.abspath(path).replace(os.sep, "/"))
    if not uri_path.startswith("/"):
        uri_path = "/" + uri_path
    try:
        con = sqlite3.connect(f"file:{uri_path}?mode=ro", uri=True, timeout=2.0)
    except sqlite3.Error:
        return 0
    try:
        row = con.execute(query).fetchone()
        return int(row[0]) if row else 0
    except (sqlite3.Error, TypeError, ValueError):
        return 0
    finally:
        con.close()


def detect(agent: Dict[str, Any]) -> Dict[str, Any]:
    root = agent.get("root", "")
    installed = bool(root) and os.path.exists(_expand(root))
    sessions_spec = agent.get("sessions") or {}
    kind = sessions_spec.get("kind", "none")

    count = 0
    path_changed = False  # root exists but the session source moved/changed
    if kind == "jsonl":
        dirs = sessions_spec.get("dirs") or []
        existing = [d for d in dirs if os.path.isdir(_expand(d))]
        count = _count_jsonl(existing)
        if installed and dirs and not existing:
            path_changed = True
    elif kind == "sqlite":
        db = sessions_spec.get("db")
        query = sessions_spec.get("query") or (
            "SELECT COUNT(*) FROM ItemTable "
            "WHERE key LIKE '%chat%' OR key LIKE '%composer%';"
        )
        if db and os.path.exists(_expand(db)):
            count = _sqlite_count(db, query)
        elif installed and db:
            path_changed = True

    return {
        "id": agent.get("id"),
        "display": agent.get("display", agent.get("id")),
        "initial": agent.get("initial", ""),
        "installed": installed,
        "sessions": count,
        "approximate": kind == "jsonl",  # counting files is an approximation
        "pathChanged": path_changed,
        "detail": agent.get("detail", root),
        "skillDir": agent.get("skillDir", ""),
    }


def main(argv: List[str] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Detect installed AI agents & session counts (read-only)."
    )
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args(argv)

    result = {
        "platform": platform_key(),
        "agents": [detect(a) for a in load_agents()],
    }

    if args.json:
        print(json.dumps(result, ensure_ascii=False))
        return 0

    print(f"agent status ({result['platform']})")
    for a in result["agents"]:
        if not a["installed"]:
            state = "not installed"
        elif a["pathChanged"]:
            state = "installed, session layout changed"
        else:
            approx = "~" if a["approximate"] else ""
            state = f"{approx}{a['sessions']} sessions"
        print(f"  {a['display']:<12} {state:<36} {a['detail']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
