#!/usr/bin/env python3
"""
sqlite_reader.py — read-only readers for the two VSCode-based agents that
store chat inside a SQLite `state.vscdb`: Cursor and Antigravity.

CRITICAL SAFETY
---------------
These databases belong to a running application that holds a file lock and
stores opaque, version-migrated blobs. We open EVERY connection with
`file:...?mode=ro` (immutable read-only) and NEVER write. This reader is
strictly read-only; there is no writer counterpart by design.

Cursor layout (verified on-disk)
--------------------------------
  globalStorage/state.vscdb  (table: cursorDiskKV)
    composerData:<composerId>  -> {name, createdAt, lastUpdatedAt,
                                   fullConversationHeadersOnly:[{bubbleId,type}]}
    bubbleId:<composerId>:<bubbleId> -> {type:1|2, text, richText, ...}
      type 1 = user, type 2 = assistant
  fullConversationHeadersOnly is the ORDERED message list for a composer.
  Project mapping: composers are global (not tied to a workspace folder in an
  easily reversible way), so `project` is left as the composer name / id.

Antigravity layout (partially verified)
---------------------------------------
  Same VSCode SQLite shape. workspaceStorage/<hash>/state.vscdb and
  globalStorage/state.vscdb both have `ItemTable`; chat index lives at
  `chat.ChatSessionStore.index` = {version, entries}. On the probed machine
  every entries list was EMPTY (no real Antigravity conversations), so the
  message-body location could not be confirmed. This reader parses what it
  can and degrades gracefully, recording a lossy_note. It will light up
  automatically once a machine has real Antigravity sessions.
"""

from __future__ import annotations

import glob
import json
import os
import sqlite3
import sys
from typing import Any, Dict, Iterator, List, Optional
from urllib.parse import quote

from ..base import Reader
from ..canonical import (
    CanonicalMessage,
    CanonicalSession,
    ROLE_ASSISTANT,
    ROLE_USER,
)
from .. import utils


def _vscode_user_dir(app: str, win_app: str = "") -> str:
    """Per-platform VSCode-style user dir for `app` (Cursor / Antigravity).

    `win_app` overrides the app-dir name on Windows when it differs
    (e.g. Antigravity's user data lives under "Antigravity IDE" there).
    """
    if sys.platform == "darwin":
        return f"~/Library/Application Support/{app}/User"
    if sys.platform.startswith("win"):
        return f"~/AppData/Roaming/{win_app or app}/User"
    return f"~/.config/{app}/User"


def _connect_ro(path: str) -> Optional[sqlite3.Connection]:
    """Open a SQLite db strictly read-only, or return None on failure."""
    if not os.path.exists(path):
        return None
    # URI form must use forward slashes and %-quoting (Windows paths contain
    # backslashes and spaces that would otherwise corrupt the URI).
    uri_path = quote(os.path.abspath(path).replace(os.sep, "/"))
    if not uri_path.startswith("/"):
        uri_path = "/" + uri_path
    try:
        return sqlite3.connect(f"file:{uri_path}?mode=ro", uri=True, timeout=2.0)
    except sqlite3.Error:
        return None


def _table_exists(con: sqlite3.Connection, name: str) -> bool:
    try:
        cur = con.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
        )
        return cur.fetchone() is not None
    except sqlite3.Error:
        return False


class CursorReader(Reader):
    agent_id = "cursor"
    display_name = "Cursor"
    global_db = _vscode_user_dir("Cursor") + "/globalStorage/state.vscdb"

    def available(self) -> bool:
        return os.path.exists(os.path.expanduser(self.global_db))

    def iter_sessions(self) -> Iterator[CanonicalSession]:
        path = os.path.expanduser(self.global_db)
        con = _connect_ro(path)
        if con is None:
            return
        try:
            if not _table_exists(con, "cursorDiskKV"):
                return
            cur = con.execute(
                "SELECT key, value FROM cursorDiskKV WHERE key LIKE 'composerData:%'"
            )
            composers = cur.fetchall()
            for key, value in composers:
                if not value:
                    continue
                try:
                    yield self._parse_composer(con, key, value, path)
                except Exception as e:
                    stub = CanonicalSession(
                        session_id=key.split(":", 1)[-1],
                        source_agent=self.agent_id,
                        source_ref=f"{path}#{key}",
                    )
                    stub.note_lossy(f"parse error: {type(e).__name__}: {e}")
                    yield stub
        finally:
            con.close()

    def _parse_composer(
        self, con: sqlite3.Connection, key: str, value: str, path: str
    ) -> CanonicalSession:
        cid = key.split(":", 1)[-1]
        d = json.loads(value)
        sess = CanonicalSession(
            session_id=cid,
            source_agent=self.agent_id,
            source_ref=f"{path}#composerData:{cid}",
        )
        sess.created_at = utils.to_iso(d.get("createdAt"))
        sess.updated_at = utils.to_iso(d.get("lastUpdatedAt") or d.get("createdAt"))
        name = d.get("name")
        if isinstance(name, str) and name.strip():
            sess.title = name.strip()
        sess.note_lossy(
            "Cursor stores rich structured context (code chunks, diffs, tool "
            "results) in opaque blobs; only message text is extracted."
        )

        headers = d.get("fullConversationHeadersOnly")
        if not isinstance(headers, list) or not headers:
            sess.note_lossy("no conversation headers (empty or migrated composer)")
            return sess

        for h in headers:
            if not isinstance(h, dict):
                continue
            bid = h.get("bubbleId")
            btype = h.get("type")
            if not bid:
                continue
            row = con.execute(
                "SELECT value FROM cursorDiskKV WHERE key=?",
                (f"bubbleId:{cid}:{bid}",),
            ).fetchone()
            if not row or not row[0]:
                continue
            try:
                bubble = json.loads(row[0])
            except json.JSONDecodeError:
                continue
            text = bubble.get("text") or ""
            if not isinstance(text, str) or not text.strip():
                continue
            role = ROLE_USER if btype == 1 else ROLE_ASSISTANT
            sess.messages.append(CanonicalMessage(role=role, text=text))

        if not sess.title:
            sess.title = sess.derive_title()
        # project unknown from global store; use title as a soft label
        sess.project = ""
        return sess


class AntigravityReader(Reader):
    agent_id = "antigravity"
    display_name = "Antigravity"
    base = _vscode_user_dir("Antigravity", win_app="Antigravity IDE")

    def available(self) -> bool:
        return os.path.isdir(os.path.expanduser(self.base))

    def _dbs(self) -> List[str]:
        base = os.path.expanduser(self.base)
        dbs = glob.glob(os.path.join(base, "workspaceStorage", "*", "state.vscdb"))
        g = os.path.join(base, "globalStorage", "state.vscdb")
        if os.path.exists(g):
            dbs.append(g)
        return sorted(dbs)

    def iter_sessions(self) -> Iterator[CanonicalSession]:
        for path in self._dbs():
            con = _connect_ro(path)
            if con is None:
                continue
            try:
                yield from self._parse_db(con, path)
            except Exception:
                pass
            finally:
                con.close()

    def _parse_db(
        self, con: sqlite3.Connection, path: str
    ) -> Iterator[CanonicalSession]:
        if not _table_exists(con, "ItemTable"):
            return
        row = con.execute(
            "SELECT value FROM ItemTable WHERE key='chat.ChatSessionStore.index'"
        ).fetchone()
        if not row or not row[0]:
            return
        try:
            index = json.loads(row[0])
        except json.JSONDecodeError:
            return
        entries = index.get("entries")
        # entries can be a list or dict depending on version
        items: List[Dict[str, Any]] = []
        if isinstance(entries, list):
            items = [e for e in entries if isinstance(e, dict)]
        elif isinstance(entries, dict):
            items = [v for v in entries.values() if isinstance(v, dict)]

        if not items:
            # index present but empty — no real conversations on this machine
            stub = CanonicalSession(
                session_id=os.path.basename(os.path.dirname(path)),
                source_agent=self.agent_id,
                source_ref=f"{path}#chat.ChatSessionStore.index",
            )
            stub.note_lossy(
                "Antigravity chat index present but entries empty; message-body "
                "location unconfirmed (needs a machine with real sessions)."
            )
            # Yield nothing for an empty index to avoid noise.
            return

        for e in items:
            sess = CanonicalSession(
                session_id=str(e.get("id") or e.get("sessionId") or "unknown"),
                source_agent=self.agent_id,
                source_ref=f"{path}#chat.ChatSessionStore.index",
            )
            sess.title = str(e.get("title") or e.get("name") or "").strip()
            sess.created_at = utils.to_iso(e.get("createdAt") or e.get("timestamp"))
            sess.updated_at = utils.to_iso(e.get("lastUpdatedAt") or e.get("timestamp"))
            # Best-effort: some versions inline a messages array in the entry.
            msgs = e.get("messages")
            if isinstance(msgs, list):
                for m in msgs:
                    if not isinstance(m, dict):
                        continue
                    role = m.get("role") or (
                        ROLE_USER if m.get("type") in (1, "user") else ROLE_ASSISTANT
                    )
                    text = utils.flatten_text(m.get("content")) or (
                        m.get("text") if isinstance(m.get("text"), str) else ""
                    )
                    if text and text.strip():
                        sess.messages.append(
                            CanonicalMessage(
                                role=utils_norm_role(role), text=text
                            )
                        )
            else:
                sess.note_lossy(
                    "Antigravity entry carries no inline messages; body location "
                    "unconfirmed on this version."
                )
            if not sess.title:
                sess.title = sess.derive_title()
            yield sess


def utils_norm_role(role: Any) -> str:
    if role in (ROLE_USER, ROLE_ASSISTANT):
        return role
    if role in (1, "user"):
        return ROLE_USER
    if role in (2, "assistant"):
        return ROLE_ASSISTANT
    return ROLE_USER
