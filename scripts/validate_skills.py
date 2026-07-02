#!/usr/bin/env python3
"""
validate_skills.py — sanity-check every SKILL.md in the repo.

Ensures each SKILL.md has a YAML frontmatter block delimited by `---`
containing at least a non-empty `name:` and `description:`. Exits non-zero
if any skill is malformed, so CI can gate on it.

Pure standard library, cross-platform.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
NAME_RE = re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE)
DESC_RE = re.compile(r"^description:\s*(.*\S)?\s*$", re.MULTILINE)


def frontmatter(text: str) -> str | None:
    """Return the frontmatter block (between the first pair of `---`)."""
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    return text[3:end]


def check(skill_md: Path) -> list[str]:
    errors: list[str] = []
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    fm = frontmatter(text)
    if fm is None:
        return [f"{skill_md}: missing `---` frontmatter block"]
    if not NAME_RE.search(fm):
        errors.append(f"{skill_md}: frontmatter has no non-empty `name:`")
    if not DESC_RE.search(fm):
        errors.append(f"{skill_md}: frontmatter has no non-empty `description:`")
    return errors


def main() -> int:
    skill_files = sorted((REPO_ROOT / "skill").rglob("SKILL.md"))
    if not skill_files:
        print("error: no SKILL.md found under skill/", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    for f in skill_files:
        errs = check(f)
        status = "OK" if not errs else "FAIL"
        print(f"[{status}] {f.relative_to(REPO_ROOT)}")
        all_errors.extend(errs)

    if all_errors:
        print("\nProblems found:", file=sys.stderr)
        for e in all_errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(f"\nAll {len(skill_files)} SKILL.md file(s) valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
