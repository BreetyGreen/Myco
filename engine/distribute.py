#!/usr/bin/env python3
"""
distribute.py — fan a set of SKILL.md skills out into every AI agent's
repo-level skills directory, so they travel with Git and every tool on the
project can read them.

Cross-platform (macOS / Linux / Windows). Pure standard library.

Usage
-----
    # From your target project root, pull skills from a source folder:
    python3 distribute.py --src /path/to/skills-source --dest .

    # Only target specific agents:
    python3 distribute.py --src ./skills --dest . --agents claude,codex,agents

    # Preview without writing:
    python3 distribute.py --src ./skills --dest . --dry-run

Source layout expected
----------------------
Either a folder of skills:
    <src>/<skill-name>/SKILL.md
or a single skill folder that itself contains SKILL.md:
    <src>/SKILL.md
Both are handled.

Each destination gets:  <dest>/<agent-dir>/<skill-name>/SKILL.md (+ any assets)
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

# Repo-level skill directories per agent. Keys are the --agents selectors.
# These are the fallback defaults; the authoritative list lives in
# agents.json next to this file (single source of truth shared with the
# Swift app). If that file is present it OVERRIDES these built-ins, so a
# new agent / moved path only needs editing in one place.
_FALLBACK_AGENT_DIRS = {
    "claude": ".claude/skills",   # Claude Code
    "codex": ".codex/skills",     # Codex CLI (seen-in-practice path)
    "agents": ".agents/skills",   # Codex/Gemini/Cursor cross-agent convention
    "cline": ".cline/skills",     # Cline
}
_FALLBACK_DEFAULT_AGENTS = ["claude", "codex", "agents"]


def load_registry() -> tuple[dict[str, str], list[str]]:
    """Build {selector: skill-dir} and the default agent list from
    agents.json (single source of truth). Falls back to the built-ins if the
    registry is missing or malformed, so distribute.py always works."""
    reg = Path(__file__).resolve().parent / "agents.json"
    try:
        data = json.loads(reg.read_text(encoding="utf-8"))
    except Exception:
        return dict(_FALLBACK_AGENT_DIRS), list(_FALLBACK_DEFAULT_AGENTS)

    dirs: dict[str, str] = {}
    for a in data.get("agents", []):
        sel, d = a.get("id"), a.get("skillDir")
        if sel and d:
            dirs[sel] = d
    for e in data.get("extraSkillTargets", []):
        sel, d = e.get("id"), e.get("dir")
        if sel and d:
            dirs[sel] = d
    if not dirs:
        return dict(_FALLBACK_AGENT_DIRS), list(_FALLBACK_DEFAULT_AGENTS)

    defaults = [a for a in data.get("defaultDistribute", []) if a in dirs]
    if not defaults:
        defaults = list(_FALLBACK_DEFAULT_AGENTS)
    return dirs, defaults


AGENT_DIRS, DEFAULT_AGENTS = load_registry()

NAME_RE = re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE)


def find_skill_dirs(src: Path) -> list[Path]:
    """Return a list of skill directories (each containing a SKILL.md)."""
    if (src / "SKILL.md").is_file():
        return [src]
    dirs = []
    for child in sorted(src.iterdir()):
        if child.is_dir() and (child / "SKILL.md").is_file():
            dirs.append(child)
    return dirs


def skill_name(skill_dir: Path) -> str:
    """Prefer the frontmatter `name:` field; fall back to the folder name."""
    text = (skill_dir / "SKILL.md").read_text(encoding="utf-8", errors="replace")
    m = NAME_RE.search(text)
    if m:
        # strip surrounding quotes if any
        return m.group(1).strip().strip("\"'")
    return skill_dir.name


def copy_skill(skill_dir: Path, target_root: Path, name: str, dry_run: bool) -> None:
    target = target_root / name
    if dry_run:
        print(f"    would copy -> {target}")
        return
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(skill_dir, target)
    print(f"    copied -> {target}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True, type=Path,
                    help="source folder of skills (or a single skill folder)")
    ap.add_argument("--dest", required=True, type=Path,
                    help="destination project root")
    ap.add_argument("--agents", default=",".join(DEFAULT_AGENTS),
                    help=f"comma-separated agents to target "
                         f"(available: {', '.join(AGENT_DIRS)}; "
                         f"default: {','.join(DEFAULT_AGENTS)})")
    ap.add_argument("--dry-run", action="store_true",
                    help="print what would happen without writing")
    args = ap.parse_args()

    src = args.src.expanduser().resolve()
    dest = args.dest.expanduser().resolve()

    if not src.exists():
        print(f"error: --src not found: {src}", file=sys.stderr)
        return 2
    if not dest.exists():
        print(f"error: --dest not found: {dest}", file=sys.stderr)
        return 2

    agents = [a.strip() for a in args.agents.split(",") if a.strip()]
    unknown = [a for a in agents if a not in AGENT_DIRS]
    if unknown:
        print(f"error: unknown agent(s): {', '.join(unknown)}", file=sys.stderr)
        print(f"available: {', '.join(AGENT_DIRS)}", file=sys.stderr)
        return 2

    skills = find_skill_dirs(src)
    if not skills:
        print(f"error: no SKILL.md found under {src}", file=sys.stderr)
        return 1

    print(f"Source : {src}")
    print(f"Dest   : {dest}")
    print(f"Agents : {', '.join(agents)}")
    print(f"Skills : {', '.join(skill_name(s) for s in skills)}")
    print(f"{'(dry run) ' if args.dry_run else ''}Distributing...\n")

    for agent in agents:
        target_root = dest / AGENT_DIRS[agent]
        print(f"[{agent}] {AGENT_DIRS[agent]}/")
        if not args.dry_run:
            target_root.mkdir(parents=True, exist_ok=True)
        for skill_dir in skills:
            copy_skill(skill_dir, target_root, skill_name(skill_dir), args.dry_run)
        print()

    print("Done.")
    if not args.dry_run:
        print("\nNext: commit the new skill directories so they travel with Git:")
        joined = " ".join(AGENT_DIRS[a] for a in agents)
        print(f"  git add {joined} AGENTS.md")
        print('  git commit -m "chore: share skills across AI agents"')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
