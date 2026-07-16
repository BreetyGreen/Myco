#!/usr/bin/env python3
"""
jsonl_reader.py — reader for the two JSONL/event-stream agents that are
near-isomorphic: Claude Code and WorkBuddy.

Both store one session per `.jsonl` file under a per-project directory:
  Claude    : ~/.claude/projects/<encoded-cwd>/<uuid>.jsonl
  WorkBuddy : ~/.workbuddy/projects/<encoded-cwd>/<uuid>.jsonl

They differ only in per-line shape, which we normalize:

Claude line:
  {type:"user"|"assistant", uuid, parentUuid, timestamp(ISO), cwd, sessionId,
   message:{role, content}}
   - content: str OR list of blocks {type: text|thinking|tool_use|tool_result, ...}

WorkBuddy line:
  {type:"message"|"function_call"|"function_call_result"|"custom-title"|
        "file-history-snapshot",
   id, parentId, logicalParentId, timestamp(epoch ms), role, sessionId, content}
   - message.content: list of blocks {type: input_text|output_text, text}
   - function_call: {name, arguments, callId}
   - function_call_result: {name, output, callId}

One reader, two small config profiles.
"""

from __future__ import annotations

import glob
import json
import os
import re
from typing import Any, Dict, Iterator, List, Optional

from ..base import Reader
from ..canonical import (
    Block,
    BLOCK_REASONING,
    BLOCK_TEXT,
    BLOCK_TOOL_RESULT,
    BLOCK_TOOL_USE,
    CanonicalMessage,
    CanonicalSession,
    ROLE_ASSISTANT,
    ROLE_TOOL,
    ROLE_USER,
)
from .. import utils


def _real_workspace(path: str) -> str:
    """Filter out per-session scratch dirs that masquerade as workspaces.

    WorkBuddy runs every session in its own timestamp-named cwd
    (e.g. ~\\WorkBuddy\\2026-07-16-17-08-21). Presenting that as the
    session's "workspace" would mislead, so such sessions report none.
    """
    if re.match(r"^\d{4}-\d{2}-\d{2}", os.path.basename(path.rstrip("/\\"))):
        return ""
    return path


class _JsonlReader(Reader):
    """Shared implementation; subclasses set agent_id/display_name/root."""

    root: str = ""  # e.g. ~/.claude/projects

    def available(self) -> bool:
        return bool(self.root) and os.path.isdir(os.path.expanduser(self.root))

    def _session_files(self) -> List[str]:
        base = os.path.expanduser(self.root)
        return sorted(glob.glob(os.path.join(base, "**", "*.jsonl"), recursive=True))

    def iter_sessions(self) -> Iterator[CanonicalSession]:
        for path in self._session_files():
            try:
                sess = self._parse_file(path)
            except Exception as e:  # never let one bad file kill the run
                sess = CanonicalSession(
                    session_id=os.path.splitext(os.path.basename(path))[0],
                    source_agent=self.agent_id,
                    source_ref=path,
                )
                sess.note_lossy(f"parse error: {type(e).__name__}: {e}")
            if sess is not None:
                yield sess

    # ------------------------------------------------------------------
    def _parse_file(self, path: str) -> Optional[CanonicalSession]:
        rows: List[Dict[str, Any]] = []
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        if not rows:
            return None

        session_id = os.path.splitext(os.path.basename(path))[0]
        sess = CanonicalSession(
            session_id=session_id,
            source_agent=self.agent_id,
            source_ref=path,
        )
        # project: prefer explicit cwd in a row, fall back to decoding dir name
        sess.project = self._detect_project(rows, path)

        first_ts: Optional[str] = None
        last_ts: Optional[str] = None
        custom_title: Optional[str] = None

        for row in rows:
            msg, ts = self._row_to_message(row)
            # capture custom title if present (WorkBuddy)
            if row.get("type") == "custom-title":
                custom_title = row.get("customTitle") or custom_title
            if ts:
                if first_ts is None:
                    first_ts = ts
                last_ts = ts
            if msg is not None:
                if ts and not msg.timestamp:
                    msg.timestamp = ts
                sess.messages.append(msg)

        sess.created_at = first_ts
        sess.updated_at = last_ts
        sess.title = custom_title or sess.derive_title()
        return sess

    def _detect_project(self, rows: List[Dict[str, Any]], path: str) -> str:
        for row in rows:
            cwd = row.get("cwd")
            if isinstance(cwd, str) and cwd:
                return _real_workspace(cwd)
            # session_meta-ish nesting (defensive)
            meta = row.get("payload") if isinstance(row.get("payload"), dict) else None
            if meta and isinstance(meta.get("cwd"), str):
                return _real_workspace(meta["cwd"])
        # fall back: decode the parent dir name
        parent = os.path.basename(os.path.dirname(path))
        return _real_workspace(utils.decode_project_dir(parent))

    # ------------------------------------------------------------------
    def _row_to_message(self, row: Dict[str, Any]):
        """Return (CanonicalMessage|None, iso_ts|None) for one raw line."""
        rtype = row.get("type")
        ts = utils.to_iso(row.get("timestamp"))

        # ---- Claude-style: type in {user, assistant}, body in row["message"]
        if rtype in ("user", "assistant"):
            m = row.get("message") or {}
            role = m.get("role") or (
                ROLE_USER if rtype == "user" else ROLE_ASSISTANT
            )
            content = m.get("content")
            text, blocks = self._extract_content_blocks(content)
            meta: Dict[str, Any] = {}
            if m.get("model"):
                meta["model"] = m["model"]
            usage = m.get("usage")
            if isinstance(usage, dict):
                tin = usage.get("input_tokens")
                tout = usage.get("output_tokens")
                if tin is not None or tout is not None:
                    meta["tokens"] = {"in": tin, "out": tout}
            return (
                CanonicalMessage(
                    role=self._norm_role(role),
                    text=text,
                    blocks=blocks,
                    meta=meta,
                ),
                ts,
            )

        # ---- WorkBuddy-style message: type == "message"
        if rtype == "message":
            role = row.get("role") or ROLE_USER
            text, blocks = self._extract_content_blocks(row.get("content"))
            return (
                CanonicalMessage(
                    role=self._norm_role(role), text=text, blocks=blocks
                ),
                ts,
            )

        # ---- tool call (WorkBuddy function_call)
        if rtype == "function_call":
            name = row.get("name", "")
            args = row.get("arguments")
            args_text = args if isinstance(args, str) else json.dumps(
                args, ensure_ascii=False
            )
            blk = Block(
                kind=BLOCK_TOOL_USE,
                text=f"[tool_use] {name}({utils.truncate(args_text, 800)})",
                raw={"name": name, "arguments": args, "call_id": row.get("callId")},
            )
            return (
                CanonicalMessage(role=ROLE_ASSISTANT, text="", blocks=[blk]),
                ts,
            )

        # ---- tool result (WorkBuddy function_call_result)
        if rtype == "function_call_result":
            out = row.get("output")
            out_text = utils.flatten_text(out) or (
                out if isinstance(out, str) else json.dumps(out, ensure_ascii=False)
            )
            blk = Block(
                kind=BLOCK_TOOL_RESULT,
                text=f"[tool_result] {row.get('name','')}: "
                + utils.truncate(out_text, 1500),
                raw={"name": row.get("name"), "call_id": row.get("callId")},
            )
            return (
                CanonicalMessage(role=ROLE_TOOL, text="", blocks=[blk]),
                ts,
            )

        # everything else (file-history-snapshot, custom-title, etc.) is skipped
        return (None, ts)

    # ------------------------------------------------------------------
    def _extract_content_blocks(self, content: Any):
        """Return (text, [Block]) from a Claude/WorkBuddy content field."""
        blocks: List[Block] = []
        text_parts: List[str] = []

        if isinstance(content, str):
            return content, blocks

        if isinstance(content, list):
            for b in content:
                if not isinstance(b, dict):
                    if isinstance(b, str):
                        text_parts.append(b)
                    continue
                btype = b.get("type")
                if btype in ("text", "input_text", "output_text"):
                    t = b.get("text", "")
                    if t:
                        text_parts.append(t)
                        blocks.append(Block(kind=BLOCK_TEXT, text=t))
                elif btype == "thinking":
                    t = b.get("thinking", "")
                    blocks.append(
                        Block(kind=BLOCK_REASONING, text=t, raw={"kind": "thinking"})
                    )
                elif btype == "tool_use":
                    name = b.get("name", "")
                    inp = b.get("input")
                    inp_text = json.dumps(inp, ensure_ascii=False) if inp else ""
                    blocks.append(
                        Block(
                            kind=BLOCK_TOOL_USE,
                            text=f"[tool_use] {name}({utils.truncate(inp_text, 800)})",
                            raw={"name": name, "input": inp, "id": b.get("id")},
                        )
                    )
                elif btype == "tool_result":
                    res = b.get("content")
                    res_text = utils.flatten_text(res)
                    blocks.append(
                        Block(
                            kind=BLOCK_TOOL_RESULT,
                            text="[tool_result] " + utils.truncate(res_text, 1500),
                            raw={"tool_use_id": b.get("tool_use_id")},
                        )
                    )
            return ("\n".join(text_parts), blocks)

        # dict or other
        return (utils.flatten_text(content), blocks)

    @staticmethod
    def _norm_role(role: Optional[str]) -> str:
        if role in (ROLE_USER, ROLE_ASSISTANT, ROLE_TOOL):
            return role
        if role == "system" or role == "developer":
            return "system"
        return ROLE_USER if role is None else str(role)


class ClaudeReader(_JsonlReader):
    agent_id = "claude"
    display_name = "Claude Code"
    root = "~/.claude/projects"


class WorkBuddyReader(_JsonlReader):
    agent_id = "workbuddy"
    display_name = "WorkBuddy"
    root = "~/.workbuddy/projects"
