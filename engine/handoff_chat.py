#!/usr/bin/env python3
"""
handoff_chat.py — "conversation handoff" CLI (v2 companion to sync_chats.py).

Take one full conversation from agent A and turn it into a paste-ready block
so you can CONTINUE it in agent B, in a brand-new (legitimately-id'd) session.

    Nothing is forged. Nothing is written into any agent's database. We only
    READ agent A's history and PRODUCE text for you to paste into agent B.

Typical flow
------------
    # 1) See what conversations you have (optionally filter by agent/keyword)
    python3 handoff_chat.py --list
    python3 handoff_chat.py --list --agents codex --search 简历

    # 2) Pick one (by shortid / full id / title substring) and build the pack.
    #    By default it BOTH saves a .md file AND copies to the clipboard.
    python3 handoff_chat.py --session 019e71ce
    python3 handoff_chat.py --session "简历" --agents codex

    # 3) Paste (Cmd/Ctrl+V) into agent B's input box. Done — continue chatting.

Modes
-----
    --mode auto     (default) verbatim if it fits; else recap + key turns
    --mode full     verbatim, tools collapsed to one line (may be very long)
    --mode summary  always recap + key turns (shortest)

Read-only. Cross-platform. Pure standard library.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import List, Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from chatsync.canonical import CanonicalSession  # noqa: E402
from chatsync.handoff import (  # noqa: E402
    DEFAULT_MAX_CHARS,
    VALID_MODES,
    build_handoff,
)
from chatsync import utils  # noqa: E402
from chatsync.readers.jsonl_reader import ClaudeReader, WorkBuddyReader  # noqa: E402
from chatsync.readers.codex_reader import CodexReader  # noqa: E402
from chatsync.readers.sqlite_reader import (  # noqa: E402
    AntigravityReader,
    CursorReader,
)

REGISTRY = {
    "claude": ClaudeReader,
    "workbuddy": WorkBuddyReader,
    "codex": CodexReader,
    "cursor": CursorReader,
    "antigravity": AntigravityReader,
}
DEFAULT_AGENTS = list(REGISTRY.keys())


def _collect(agents: List[str]) -> List[CanonicalSession]:
    out: List[CanonicalSession] = []
    for agent in agents:
        cls = REGISTRY.get(agent)
        if cls is None:
            print(f"  ! unknown agent '{agent}', skipping", file=sys.stderr)
            continue
        reader = cls()
        if not reader.available():
            continue
        for s in reader.read_all():
            if s.non_empty_messages():
                out.append(s)
    # newest first
    out.sort(key=lambda s: (s.updated_at or s.created_at or ""), reverse=True)
    return out


def _short(sess: CanonicalSession) -> str:
    return sess.session_id.replace(":", "_")[:8] or "noid"


def _matches(sess: CanonicalSession, needle: str) -> bool:
    if not needle:
        return True
    n = needle.lower()
    if n in _short(sess).lower():
        return True
    if n in (sess.session_id or "").lower():
        return True
    if n in (sess.title or sess.derive_title()).lower():
        return True
    return False


def _print_table(sessions: List[CanonicalSession], limit: int = 60) -> None:
    print(f"{'#':>3}  {'AGENT':<11} {'DATE':<10} {'MSGS':>5}  {'SHORTID':<9} TITLE")
    print("-" * 92)
    for i, s in enumerate(sessions[:limit], 1):
        date = (s.created_at or s.updated_at or "")[:10] or "----------"
        title = (s.title or s.derive_title())[:46]
        print(
            f"{i:>3}  {s.source_agent:<11} {date:<10} "
            f"{len(s.non_empty_messages()):>5}  {_short(s):<9} {title}"
        )
    if len(sessions) > limit:
        print(f"... (+{len(sessions) - limit} more; narrow with --agents / --search)")


def _print_json(sessions: List[CanonicalSession], limit: int = 200) -> None:
    """Machine-readable listing for the Myco app (avoids fixed-width column
    parsing, which breaks on CJK titles). One JSON object to stdout."""
    items = []
    for s in sessions[:limit]:
        date = (s.updated_at or s.created_at or "")[:10]
        items.append({
            "shortid": _short(s),
            "session_id": s.session_id,
            "agent": s.source_agent,
            "title": (s.title or s.derive_title()),
            "msgs": len(s.non_empty_messages()),
            "date": date,
        })
    print(json.dumps({"count": len(sessions), "sessions": items}, ensure_ascii=False))


def main(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(
        description="Build a conversation-handoff package to continue an "
        "agent-A chat inside agent B (read-only; no id forging; no db writes)."
    )
    p.add_argument(
        "--agents",
        default=",".join(DEFAULT_AGENTS),
        help="comma-separated source agents to scan: " + ",".join(DEFAULT_AGENTS),
    )
    p.add_argument("--list", action="store_true", help="list candidate sessions and exit")
    p.add_argument("--json", dest="as_json", action="store_true",
                   help="with --list: emit machine-readable JSON (for the Myco app)")
    p.add_argument("--search", default="", help="filter sessions by title/id substring")
    p.add_argument(
        "--session",
        default="",
        help="select a session by shortid / full id / title substring",
    )
    p.add_argument(
        "--mode",
        default="auto",
        choices=list(VALID_MODES),
        help="packing mode (default: auto)",
    )
    p.add_argument(
        "--max-chars",
        type=int,
        default=DEFAULT_MAX_CHARS,
        help=f"char budget before auto-degrade (default {DEFAULT_MAX_CHARS})",
    )
    p.add_argument(
        "--out",
        default="",
        help="write the handoff package to this .md file "
        "(default: ./handoff-<agent>-<shortid>.md unless --no-file)",
    )
    p.add_argument("--no-file", action="store_true", help="do not write a file")
    p.add_argument("--no-clip", action="store_true", help="do not copy to clipboard")
    p.add_argument(
        "--print", dest="to_stdout", action="store_true",
        help="also print the full package to stdout",
    )
    args = p.parse_args(argv)

    agents = [a.strip() for a in args.agents.split(",") if a.strip()]
    sessions = _collect(agents)
    if args.search:
        sessions = [s for s in sessions if _matches(s, args.search)]

    if not sessions:
        # JSON consumers (the app) expect a valid empty payload, not an error.
        if args.as_json and (args.list or not args.session):
            print(json.dumps({"count": 0, "sessions": []}, ensure_ascii=False))
            return 0
        print("No sessions found for the given filters.", file=sys.stderr)
        return 1

    # --list, or no selector given -> show the listing to help the user pick.
    if args.list or not args.session:
        if args.as_json:
            _print_json(sessions)
            return 0
        _print_table(sessions)
        if not args.list:
            print(
                "\nPick one and run again, e.g.:\n"
                f"  python3 {os.path.basename(__file__)} --session <SHORTID>"
            )
        return 0

    # Resolve the selection.
    matches = [s for s in sessions if _matches(s, args.session)]
    if not matches:
        print(f"No session matches '{args.session}'.", file=sys.stderr)
        return 1
    if len(matches) > 1:
        print(f"'{args.session}' is ambiguous — {len(matches)} matches:\n")
        _print_table(matches)
        print("\nNarrow it down (use a SHORTID or a more specific title).")
        return 2

    sess = matches[0]
    result = build_handoff(sess, mode=args.mode, max_chars=args.max_chars)

    # Report.
    agent = sess.source_agent
    short = _short(sess)
    print("Conversation handoff built")
    print(f"  source     : {agent}  ({sess.title or sess.derive_title()})")
    print(f"  shortid    : {short}")
    print(f"  mode used  : {result.mode_used}")
    print(f"  turns      : {result.turns_included}/{result.turns_total}")
    print(f"  size       : {result.char_count} chars")
    if result.degraded or result.note:
        print(f"  note       : {result.note}")

    # Write file (default on).
    if not args.no_file:
        out_path = args.out or f"./handoff-{agent}-{short}.md"
        out_path = os.path.abspath(out_path)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as fh:
            fh.write(result.text)
        print(f"  file       : {out_path}")

    # Clipboard (default on).
    if not args.no_clip:
        ok = utils.copy_to_clipboard(result.text)
        print(f"  clipboard  : {'copied ✓ (just paste into agent B)' if ok else 'unavailable (no pbcopy/clip/xclip found)'}")

    if args.to_stdout:
        print("\n" + "=" * 72 + "\n")
        print(result.text)

    print(
        "\nNext: open agent B (e.g. WorkBuddy), start a NEW chat, paste (Cmd/Ctrl+V), send.\n"
        "      B will read the history and continue — in its own legit new session."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
