# AGENTS.md — orientation for AI agents & contributors

> This file is read automatically by Codex CLI (and often symlinked to
> `CLAUDE.md`). It's the fastest way for an AI agent — or a human — to get
> oriented after a fresh `git clone`, on a brand-new machine, and continue the
> work. Keep it short and factual.

## What this project is

**Myco** — "the mycelial layer for your AI agents." A self-contained macOS
menu-bar app that connects the AI coding agents on your Mac so they can share
**skills**, hand off **conversations**, and unify **history**. The repo
directory is still named `multi-agent-skill-sharing/` for historical reasons;
the product is **Myco**.

Three capabilities, all **read-only** toward the agents (Myco never writes back
into any agent's storage):

- **Share skills** — fan one `SKILL.md` out to each agent's repo skill dir.
- **Relay conversations** — package one chat as paste-ready text to continue in
  another agent, in a legitimately new session (no forged IDs, no DB writes).
- **Unify history** — read every agent's local transcripts into one neutral,
  searchable, offline timeline.

## Architecture (two layers)

| Layer | Where | What |
|-------|-------|------|
| **App — macOS** | `app/Sources/Myco/` | SwiftUI + AppKit menu-bar app (`NSStatusItem` + `NSPopover`). Builds with **Command Line Tools only — no Xcode**. |
| **App — Windows** | `app-windows/` | WPF tray app (WinForms `NotifyIcon` + WPF panel, **zero NuGet deps**). Builds with the **.NET 8 SDK** (`dotnet build`). |
| **Engine** (the brains) | `engine/` | Pure **Python-stdlib** CLIs both apps call via `Process`. No third-party deps. |

The native apps are thin shells; all real work (detection, distribution, chat
parsing, handoff) lives in the Python engine. The installed macOS `.app`
bundles the engine into `Contents/Resources/engine/` and uses macOS's own
`python3`; the Windows zip ships the engine next to `Myco.exe` plus an
embedded python.org Python — both fully self-contained. On Windows, agent
detection also runs in the engine (`agent_status.py --json`) rather than being
reimplemented in C#.

### Single source of truth: `engine/agents.json`

**This is the most important file to understand.** It's the one registry of
every agent Myco knows about — id, display name, detection path, session-reading
method (`jsonl` dirs or `sqlite` db+query), and skill directory. The Swift app
(`AgentDetector.swift`), the Windows app (via `agent_status.py`) **and** the
Python engine (`distribute.py`) all read it, so detection and
skill-distribution can never drift apart. An agent may carry an optional
`"windows"` block that shallow-overrides its paths on Windows (Cursor /
Antigravity live under `%APPDATA%` there); readers that don't understand the
key (Swift) simply ignore it.

**To add an agent or fix a moved path, edit `agents.json` only** — no recompile,
no touching two code paths. Currently 5 detected agents:
`claude` · `workbuddy` · `codex` · `cursor` · `antigravity`
(plus `.agents` and `.cline` as extra skill-distribution targets).

## Key files

```
engine/agents.json        # ★ single source of truth (agents, paths, skill dirs)
engine/distribute.py      # skill fan-out (Share)         — reads agents.json
engine/agent_status.py    # agent detection as JSON       — reads agents.json
engine/handoff_chat.py    # package one chat (Relay)      — has --list --json
engine/sync_chats.py      # aggregate history (History) → archive + HTML
engine/chatsync/          # canonical message model + per-agent readers + exporters
engine/validate_skills.py # CI: checks every SKILL.md frontmatter
app/Sources/Myco/AgentDetector.swift  # reads agents.json, detects installs
app/Sources/Myco/PythonBridge.swift   # Process bridge to the engine
app/build.sh              # swift build -c release → assembles Myco.app
app/package_dmg.sh        # produce the distributable .dmg
app-windows/PythonBridge.cs  # Windows Process bridge (same lookup order)
app-windows/build.ps1     # dotnet publish → self-contained Myco-win zip
skills/.../SKILL.md        # the portable skill Myco ships & distributes
docs/                     # INSTALL (per-tool paths) + user guides + design notes
docs/RELEASING.md         # ★ how to cut a release, entirely from Windows
CHANGELOG.md              # ★ read this to see where the project is right now
```

## Build & verify (macOS)

```bash
# Build the app (Command Line Tools only, no Xcode)
cd app && ./build.sh && open Myco.app

# Exercise the engine directly (no app needed)
python3 engine/distribute.py --dry-run          # what skill fan-out would write
python3 engine/agent_status.py                  # detected agents + session counts
python3 engine/handoff_chat.py --list --json    # real sessions as JSON
python3 engine/validate_skills.py               # CI's skill-frontmatter check
```

## Build & verify (Windows)

```powershell
# Build & run (needs the .NET 8 SDK; engine works with any Python 3)
dotnet build app-windows\Myco.csproj -c Release
$env:MYCO_REPO = (Get-Location); app-windows\bin\Release\net8.0-windows\Myco.exe

# Package the self-contained distributable zip (downloads embeddable Python)
app-windows\build.ps1
```

Preview hooks (both apps): `MYCO_PREVIEW=1` shows the panel as a normal
window, `MYCO_TAB` picks the tab, `MYCO_SHOT=<png>` self-renders a screenshot
(`MYCO_SHOT_QUIT`, `MYCO_SHOT_DELAY`, `MYCO_THEME=light` also supported on
Windows).

CI (`.github/workflows/ci.yml`) validates every `SKILL.md` and dry-runs the
distributor on every push/PR, plus a macOS `swift build` job.

## How to continue this project on a new machine

1. `git clone` the repo and read **`CHANGELOG.md` top-to-bottom** — the
   `[Unreleased]` and latest version sections tell you exactly what's done and
   what changed last.
2. Read **this file** and **`engine/agents.json`** to understand the moving
   parts.
3. Build with `app/build.sh`; smoke-test the engine with the commands above.

**What does NOT travel with the repo** (see `.gitignore`) — these are local and
private, so a fresh clone won't have them, and that's intentional:

- `.workbuddy/` — local agent memory / private notes.
- `chat-archive/` and `handoff-*.md` — contain **real private conversations**.
- `app/.build/`, `app/Myco.app/`, `app/*.dmg`, `app/*.icns` — build artifacts
  (regenerated by `build.sh` / `package_dmg.sh`).
- `app-windows/bin/`, `app-windows/obj/`, `app-windows/dist/` — Windows build
  artifacts (regenerated by `dotnet build` / `build.ps1`).

The **code, docs, engine, skill payload, brand assets and `agents.json`** are
all committed, so any capable AI agent can pick up development from a clean
clone using the CHANGELOG as the map. Only your private history and generated
binaries are missing — none of which block continuing the work.

## Conventions

- **Don't break the read-only invariant.** Agent SQLite DBs are opened
  `immutable=1&mode=ro`; the engine only ever produces text/files under the
  user's work dir, never writes into an agent's store.
- **Engine stays pure stdlib** — no pip dependencies (keeps the bundled app
  self-contained).
- **Adding/moving an agent = edit `agents.json`**, then update the human-facing
  docs (`docs/INSTALL.md`, `skills/.../SKILL.md`, both READMEs) and add a
  CHANGELOG entry. See `CONTRIBUTING.md`.
- Skill-discovery paths across tools drift fast; treat the tables as
  "verified 2026-07" and re-check vendor docs if something doesn't resolve.
