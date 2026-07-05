# v0.2.0 — Conduit + cross-agent chat sync

This release grows the project from "share one skill across agents" into a
full **three-layer** toolkit for working across multiple AI coding agents —
and ships a native macOS menu-bar app to drive it all.

> **one workspace, every agent**

## Highlights

### ① Share skills (since v0.1.0)
The original portable `SKILL.md` + `scripts/distribute.py` fan-out — install a
skill once into every agent's repo-level dir so it travels with Git.

### ② Sync & hand off conversations (new)
Your chat histories are as siloed as your skills. Two **read-only, pure-stdlib**
tools bridge Claude Code · WorkBuddy · Codex CLI · Cursor · Antigravity:

- **`scripts/sync_chats.py`** — aggregate every detected agent's local history
  into one neutral, searchable archive + an offline merged HTML timeline.
- **`scripts/handoff_chat.py`** — package one conversation as paste-ready text
  so another agent can continue it in a **legitimately new session** — no
  forged IDs, no DB writes, no fake history injection.

### ③ Conduit — native macOS menu-bar app (new)
A tray app that wraps all of the above behind a clean UI:

- **Native & tiny** — SwiftUI + AppKit (`NSStatusItem` + `NSPopover`), builds
  with **Command Line Tools only, no Xcode**.
- **Read-only by design** — SQLite opened `immutable=1&mode=ro`; detection and
  history reads never mutate your data.
- **Self-contained** — the Python core is bundled into `Contents/Resources`;
  the writable work dir lives under `~/Documents/Conduit`.

## Install the app

Download **`Conduit-0.1.0.dmg`** below, open it, and drag **Conduit.app** into
**Applications**. It's ad-hoc signed, so on first launch use
**right-click → Open** to get past Gatekeeper. The icon appears at the right of
your menu bar.

Prefer source? `cd app && ./build.sh && open Conduit.app` (see `app/README.md`).

## Notes & caveats

- The app is **macOS-only**; the Python CLIs (`distribute` / `sync_chats` /
  `handoff_chat`) remain cross-platform.
- Chat archives and hand-off packages contain **real private conversations** —
  they're git-ignored by default and never committed.
- Skill-discovery paths across agents change fast; everything verified 2026-07.
  PRs to keep paths current are very welcome.

**Full changelog:** https://github.com/BreetyGreen/multi-agent-skill-sharing/compare/v0.1.0...v0.2.0
