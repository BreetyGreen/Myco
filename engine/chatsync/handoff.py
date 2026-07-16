#!/usr/bin/env python3
"""
handoff.py — build a "conversation handoff" package from one CanonicalSession.

The goal (see docs/V2_CHAT_SYNC_DESIGN.md, "context handoff"):
    Take a full conversation from agent A (e.g. Codex) and turn it into ONE
    block of formatted text. You paste that text as the first message of a
    brand-new session in agent B (e.g. WorkBuddy). B reads the "story so far"
    and continues seamlessly.

What this is NOT:
    - It does NOT forge IDs. B mints its own legitimate new session id.
    - It does NOT write into any agent's database. It only produces text.

Three packing modes:
    full     — verbatim user + assistant text; tool calls collapsed to 1 line.
    summary  — user text verbatim, assistant text truncated, tools dropped.
    auto     — try `full`; if it exceeds the char budget, degrade to a
               "recap + head/tail key-turn window" that fits the budget.
               (recommended: honest about the physical context-length limit)

Pure standard library.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List, Optional, Tuple

from .canonical import (
    BLOCK_TOOL_USE,
    ROLE_ASSISTANT,
    ROLE_USER,
    CanonicalSession,
    CanonicalMessage,
    human_content,
)
from . import utils

MODE_FULL = "full"
MODE_SUMMARY = "summary"
MODE_AUTO = "auto"
VALID_MODES = (MODE_AUTO, MODE_FULL, MODE_SUMMARY)

# Default character budget for `auto` before it degrades. ~48k chars is a
# conservative, model-agnostic stand-in for "fits comfortably in context".
DEFAULT_MAX_CHARS = 48_000

# Per-message caps used when degrading.
_ASSISTANT_TRUNC = 1_200
_USER_TRUNC = 4_000

AGENT_DISPLAY = {
    "claude": "Claude Code",
    "workbuddy": "WorkBuddy",
    "codex": "Codex CLI",
    "cursor": "Cursor",
    "antigravity": "Antigravity",
}


@dataclass
class HandoffResult:
    text: str
    mode_used: str  # full | summary | window
    char_count: int
    turns_included: int
    turns_total: int
    degraded: bool
    note: str = ""


# ---------------------------------------------------------------------------
# Turn extraction
# ---------------------------------------------------------------------------

def _clean_turns(sess: CanonicalSession) -> List[Tuple[str, str, List[str]]]:
    """Flatten a session into (role, text, tool_labels) tuples.

    - user text is de-noised via human_content() (strips <system-reminder> etc).
    - assistant text is kept as-is.
    - tool_labels: short one-line labels for any tool_use blocks in the message.
    - system/tool-only messages are dropped (they don't help a human-facing recap).
    """
    turns: List[Tuple[str, str, List[str]]] = []
    for m in sess.messages:
        if m.role == ROLE_USER:
            body = human_content(m.text)
            if body:
                turns.append((ROLE_USER, body, []))
        elif m.role == ROLE_ASSISTANT:
            body = (m.text or "").strip()
            tool_labels: List[str] = []
            for b in m.blocks:
                if b.kind == BLOCK_TOOL_USE:
                    label = _tool_label(b)
                    if label:
                        tool_labels.append(label)
            if body or tool_labels:
                turns.append((ROLE_ASSISTANT, body, tool_labels))
        # system / tool roles: intentionally skipped for handoff
    return turns


def _tool_label(block) -> str:
    """One-line label for a tool_use block, e.g. 'WebSearch(查询…)'.

    Different readers populate blocks differently:
      - Codex:   raw={"name","call_id"}, text="[tool_use] name({json args})"
      - Claude/WB: raw may carry name + input/arguments directly
    So we resolve the tool name from raw, then hunt a short argument hint from
    raw args first, falling back to parsing the block.text payload.
    """
    raw = block.raw or {}
    name = raw.get("name") or raw.get("tool") or ""
    hint = ""
    args = raw.get("arguments") or raw.get("input") or raw.get("args")
    if isinstance(args, str):
        hint = args
    elif isinstance(args, dict):
        for k in ("query", "command", "cmd", "description", "path", "prompt"):
            v = args.get(k)
            if isinstance(v, str) and v.strip():
                hint = v.strip()
                break
    # Fallback: parse the "[tool_use] name(<hint>)" text produced by readers.
    if not name and block.text:
        m = re.match(r"\s*(?:\[tool_use\]\s*)?([A-Za-z0-9_\-]+)\s*\(", block.text)
        if m:
            name = m.group(1)
    if not hint and block.text:
        # take the inside of the first (...) and shorten hard
        m = re.search(r"\((.*)\)\s*$", block.text.strip(), re.DOTALL)
        inside = m.group(1) if m else ""
        inside = re.sub(r"\s+", " ", inside).strip().strip("{}\"")
        hint = inside
    name = name or "tool"
    hint = utils.truncate(hint.replace("\n", " "), 48) if hint else ""
    return f"{name}({hint})" if hint else f"{name}"


# ---------------------------------------------------------------------------
# Rendering helpers
# ---------------------------------------------------------------------------

def _label(role: str) -> str:
    return "【用户】" if role == ROLE_USER else "【助手】"


def _header(sess: CanonicalSession, turns_total: int) -> str:
    agent = AGENT_DISPLAY.get(sess.source_agent, sess.source_agent)
    title = sess.title or sess.derive_title()
    when = (sess.created_at or sess.updated_at or "")[:19].replace("T", " ")
    lines = [
        "==================== 会话接力 · Conversation Handoff ====================",
        f"来源产品 (from) : {agent}",
        f"原会话标题       : {title}",
    ]
    if sess.project:
        lines.append(f"所属工作空间     : {sess.project}")
    if when:
        lines.append(f"原会话时间       : {when}")
    lines.append(f"原会话轮次       : {turns_total} 轮 (user+assistant)")
    lines.append("")
    lines.append(
        "说明：以下是我此前在【" + agent + "】里的一段完整对话历史。"
        "请把它当作我们对话的前情背景读完，然后我们在这里【接着往下聊】——"
        "你无需重复已经完成的工作，直接基于这些上下文继续即可。"
    )
    if sess.project:
        lines.append(
            "工作空间提示：这段对话发生在本地项目 " + sess.project + " 中。"
            "本接力包只承载【对话层】上下文；如果你能访问该目录，请先读取其中的"
            "代码、文档与 git 历史作为【代码层】上下文，两层互补后再继续。"
        )
    lines.append("=" * 72)
    return "\n".join(lines)


def _footer() -> str:
    return (
        "=" * 72
        + "\n以上是前情历史。现在请基于这些上下文，我们继续。"
        + "\n(若上文因长度做过精简，可在有需要时让我补充被省略的细节。)"
    )


def _recap(turns: List[Tuple[str, str, List[str]]], max_points: int = 8) -> str:
    """A lightweight extractive recap: the user's asks + a few tool actions.

    No LLM here — this is a deterministic, dependency-free digest built from
    the user's own questions (the clearest signal of intent) plus notable
    tool actions. It's meant to orient agent B, not to be a perfect summary.
    """
    user_points: List[str] = []
    tool_points: List[str] = []
    for role, text, tools in turns:
        if role == ROLE_USER and text.strip():
            first = text.strip().splitlines()[0]
            user_points.append(utils.truncate(first, 120))
        for t in tools:
            tool_points.append(t)
    lines = ["## 前情提要（自动提取，非 AI 总结）", ""]
    if user_points:
        lines.append("你在原对话里先后提出：")
        for i, p in enumerate(user_points[:max_points], 1):
            lines.append(f"  {i}. {p}")
        if len(user_points) > max_points:
            lines.append(f"  …（另有 {len(user_points) - max_points} 个后续追问，正文中完整保留）")
        lines.append("")
    if tool_points:
        # de-dup preserving order
        seen = set()
        uniq = []
        for t in tool_points:
            key = t.split("(")[0]
            if key not in seen:
                seen.add(key)
                uniq.append(t)
        lines.append("过程中助手调用过的工具（去重）：")
        lines.append("  " + " · ".join(uniq[:12]))
        lines.append("")
    return "\n".join(lines)


def _render_full(turns: List[Tuple[str, str, List[str]]]) -> str:
    """Verbatim user+assistant text; tool calls collapsed to one line each."""
    out: List[str] = ["## 完整对话正文", ""]
    for role, text, tools in turns:
        out.append(_label(role))
        if text:
            out.append(text.rstrip())
        for t in tools:
            out.append(f"  〔调用工具: {t}〕")
        out.append("")
    return "\n".join(out)


def _render_window(
    turns: List[Tuple[str, str, List[str]]],
    budget: int,
    head: int = 3,
    tail: int = 8,
) -> str:
    """Degraded rendering: recap + first `head` turns + last `tail` turns.

    Assistant text is truncated; the omitted middle is clearly marked. This is
    the honest answer to "the conversation is longer than the model's context".
    """
    recap = _recap(turns)
    n = len(turns)
    if n <= head + tail:
        keep_idx = list(range(n))
        omitted = 0
    else:
        keep_idx = list(range(head)) + list(range(n - tail, n))
        omitted = n - head - tail

    body: List[str] = ["## 关键轮次（首 %d + 尾 %d，中间已折叠）" % (head, tail), ""]
    prev_was_gap = False
    for i in range(n):
        if i not in keep_idx:
            if not prev_was_gap:
                body.append(f"  …〔此处省略中间 {omitted} 轮，如需可让我补充〕…")
                body.append("")
                prev_was_gap = True
            continue
        prev_was_gap = False
        role, text, tools = turns[i]
        body.append(_label(role))
        if text:
            cap = _USER_TRUNC if role == ROLE_USER else _ASSISTANT_TRUNC
            body.append(utils.truncate(text.rstrip(), cap))
        for t in tools:
            body.append(f"  〔调用工具: {t}〕")
        body.append("")
    return recap + "\n" + "\n".join(body)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def build_handoff(
    sess: CanonicalSession,
    mode: str = MODE_AUTO,
    max_chars: int = DEFAULT_MAX_CHARS,
) -> HandoffResult:
    """Produce a handoff package for `sess`. See module docstring for modes."""
    if mode not in VALID_MODES:
        mode = MODE_AUTO
    turns = _clean_turns(sess)
    turns_total = len(turns)
    header = _header(sess, turns_total)
    footer = _footer()

    def _assemble(core: str) -> str:
        return header + "\n\n" + core + "\n\n" + footer

    if mode == MODE_SUMMARY:
        core = _render_window(turns, max_chars, head=2, tail=6)
        text = _assemble(core)
        return HandoffResult(
            text=text,
            mode_used="window",
            char_count=len(text),
            turns_included=min(turns_total, 8),
            turns_total=turns_total,
            degraded=turns_total > 8,
            note="summary 模式：始终精简为摘要 + 关键轮次。",
        )

    # full or auto: first try verbatim
    full_core = _render_full(turns)
    full_text = _assemble(full_core)
    if mode == MODE_FULL or len(full_text) <= max_chars:
        return HandoffResult(
            text=full_text,
            mode_used="full",
            char_count=len(full_text),
            turns_included=turns_total,
            turns_total=turns_total,
            degraded=False,
            note="" if len(full_text) <= max_chars else
            f"full 模式：{len(full_text)} 字符，超过预算 {max_chars}，"
            "粘贴到目标产品时可能被上下文长度截断。",
        )

    # auto + over budget -> degrade to window
    core = _render_window(turns, max_chars)
    text = _assemble(core)
    # if still over budget, tighten the tail progressively
    tail = 8
    while len(text) > max_chars and tail > 3:
        tail -= 1
        core = _render_window(turns, max_chars, head=3, tail=tail)
        text = _assemble(core)
    return HandoffResult(
        text=text,
        mode_used="window",
        char_count=len(text),
        turns_included=min(turns_total, 3 + tail),
        turns_total=turns_total,
        degraded=True,
        note=(
            f"auto 模式：全文约 {len(full_text)} 字符，超过预算 {max_chars}，"
            "已自动降级为「前情提要 + 首尾关键轮次」以适配上下文长度。"
            "完整正文仍保存在归档的 .md / .json 中。"
        ),
    )
