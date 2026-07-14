# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] — 2026-07-14

Myco comes to Windows: a native tray app with full feature parity, the same
Python engine underneath, and a fresh "dopamine" visual language with real
acrylic glass on both themes.

### Added
- **Windows app (`app-windows/`)** — a native WPF tray app with full feature
  parity to the macOS menu-bar app: tray icon + dark/light themed popup panel
  with 总览 / 共享 / 接力 / 历史 / 设置, driven by the same Python engine and
  `agents.json`. Zero NuGet dependencies (WinForms `NotifyIcon` + WPF, both
  in-box); builds with the .NET 8 SDK only. `build.ps1` produces a fully
  self-contained green zip (`Myco.exe` + engine + skills + embedded
  python.org Python) — unzip and double-click, nothing to install.
- **`engine/agent_status.py`** — agent detection (installs + session counts)
  as a single engine implementation driven by `agents.json`, with `--json`
  for app frontends and a human-readable table for the CLI. The Windows app
  renders this instead of reimplementing detection in C# (Windows has no
  `sqlite3` CLI; the engine's stdlib `sqlite3` opens databases read-only).
- **Per-platform paths in `agents.json`** — an agent may carry an optional
  `"windows"` override block (Cursor / Antigravity live under `%APPDATA%` on
  Windows). Readers that don't understand the key (Swift) ignore it, so the
  macOS app is untouched.

### Changed
- **Windows app: real acrylic glass.** The panel uses Win11 accent acrylic
  (blur-behind) with translucent brand-tint layers and glassy cards —
  material parity with the macOS NSPopover blur. Pre-Win11-22H2 systems
  fall back to an opaque backdrop automatically.
- **Windows app: "dopamine" visual refresh.** New token set built around a
  neon-lime gradient (#DCF87E→#A6E14F→#64AC28) with dark ink text on every
  bright surface: a hero session-count card on 总览, pill-shaped primary
  buttons, a lime pill for the active tab, solid elevated cards with larger
  (14–20px) radii, and a flatter near-black / cream background so the lime
  is the single loud element. Both themes restyled; agent brand colors kept
  as the small colorful accents.

- **`viewer.html` is now dual-theme** — the offline chat timeline follows the
  OS dark/light preference and adds a 🌓 toggle that remembers the choice
  (localStorage). All hard-coded colors moved to CSS tokens.

### Fixed
- **`viewer.html` broke on conversations that contain `"</script>"`** (e.g.
  any chat about HTML). The inlined JSON payload now escapes `</` as `<\/`,
  so the script block can no longer be terminated early by message text.
- `chatsync` SQLite readers now build `%`-quoted forward-slash URIs, so
  read-only opens work with Windows paths (backslashes and spaces used to
  corrupt the `file:` URI), and their default Cursor / Antigravity locations
  are chosen per platform.

## [0.3.2] — 2026-07-14

Docs-only release: brings every document in line with what the app actually
does since 0.3.1, and adds an orientation file for AI agents.

### Docs
- **Aligned all docs with the real detected agent set.** README (en + zh),
  `CONTRIBUTING.md`, `docs/INSTALL.md` and the skill's `SKILL.md` said the five
  agents were Claude / Codex / Cursor / **Gemini** / **Cline**, but since 0.3.1
  the app actually detects and connects Claude Code / **WorkBuddy** / Codex CLI
  / Cursor / **Antigravity** (per `engine/agents.json`). Updated the "forest"
  narrative, the 30-second skill table, and the Share-tab examples to match;
  added WorkBuddy + Antigravity sections/rows to `INSTALL.md` and `SKILL.md`
  (Gemini/Cline kept as additional `.agents`/`.cline` distribution targets).
- **`CONTRIBUTING.md`: corrected the "adding a new agent" workflow.** It told
  contributors to edit three code paths; since 0.3.1 `engine/agents.json` is the
  single source of truth (read by both Swift and Python), so adding an agent is
  a one-file JSON edit — docs are updated separately for human readers.
- **New `AGENTS.md`** at the repo root (read by Codex directly): a concise
  orientation for any AI/contributor picking up the project from a fresh clone —
  what Myco is, the app+engine architecture, `agents.json` as the source of
  truth, build steps, and exactly what does/doesn't travel with the repo.

## [0.3.1] — 2026-07-06

Bug-fix release: fixes the README logo (invisible on GitHub's dark theme),
unifies the agent list into one registry, and wires the app to real chat data.

### Added
- **`engine/agents.json`** — a single source of truth for every agent Myco
  knows about (id, display, detection path, session-reading method, skill
  directory). Both the Swift app (`AgentDetector`) and the Python engine
  (`distribute.py`) read it, so detection and skill-distribution can never
  drift apart again. Adding an agent / moving a path is now a one-line JSON
  edit — no recompile.
- **Dark-theme logo** (`assets/logo-wordmark-dark.png`) + a `<picture>` switch
  in both READMEs so the wordmark is visible on light *and* dark GitHub themes.
- **`handoff_chat.py --json`** — machine-readable session listing (avoids
  fixed-width column parsing that broke on CJK titles).

### Fixed
- **README logo no longer disappears on GitHub.** The wordmark was still the old
  `skill·share` art with near-black text (`#16171D`) on a transparent
  background — invisible on GitHub's dark theme. Rebranded to `myco` and made
  theme-aware.
- **Two divergent agent lists reconciled.** Detection knew 5 agents
  (claude/workbuddy/codex/cursor/antigravity) while distribution knew a
  different 4 (claude/codex/agents/cline). Both now come from `agents.json`;
  WorkBuddy/Cursor/Antigravity are now valid skill targets too.
- **History/Relay show real sessions**, not placeholder titles — the app now
  calls the engine's `--list --json` and parses actual conversations.
- Session counts derived from counting `*.jsonl` files are now labelled
  **"约 N"** (approximate) instead of implying an exact number.

### Changed
- Agent detection reports **"结构已变"** when an agent's root exists but its
  session store moved, instead of silently showing "not installed".
- `countJSONL` gained a lightweight mtime-keyed cache to avoid re-walking large
  history trees on every panel open.


## [0.3.0] — 2026-07-06

**Rebrand to Myco** and reposition the whole project around a single product:
the Myco menu-bar app. Skill-sharing and chat-sync are no longer standalone
tools you install separately — they're capabilities *inside* Myco, driven by an
internal engine the user never has to touch.

### Changed
- **Renamed the product to `Myco`** ("the mycelial layer for your AI agents").
  App target, bundle id (`com.myco.app`), tray wordmark, slogan, DMG, work dir
  (`~/Documents/Myco`) and all `MYCO_*` env vars updated. The old `Conduit`
  name is gone everywhere in code and docs.
- **Directory refactor** (history-preserving `git mv`):
  - `scripts/` → **`engine/`** — reframed as Myco's internal Python engine,
    not a set of standalone CLIs.
  - `skill/` → **`skills/`** — the SKILL.md payload Myco ships and distributes.
  - `app/Sources/Conduit/` → **`app/Sources/Myco/`**.
- **README (en + zh) fully rewritten** around a single narrative: Myco is a Mac
  app you download and install; sharing skills / handing off chats / unified
  history are its built-in features. Download-first, with a "⬇ Download" button;
  the CLI engine is documented only in a "for contributors" section.
- `build.sh` / `package_dmg.sh` / `PythonBridge.swift` / CI updated to the new
  `engine/` + `skills/` paths; app still builds with Command Line Tools only.

### Fixed
- `validate_skills.py` now scans `skills/` (was hardcoded to the old `skill/`).


## [0.2.0] — 2026-07-05

Grows the project into a **three-layer** cross-agent toolkit and ships a native
macOS menu-bar app.

### Added
- **`scripts/chatsync/`** — a read-only, pure-stdlib engine to sync chat
  histories across Claude Code, WorkBuddy, Codex CLI, Cursor and Antigravity:
  a canonical message model, per-agent readers (jsonl / codex / sqlite), and
  HTML-timeline + archive exporters.
- **`scripts/sync_chats.py`** — aggregate every detected agent's history into
  one neutral, searchable archive + an offline merged HTML timeline.
- **`scripts/handoff_chat.py`** — package one conversation as paste-ready text
  so another agent can continue it in a legitimately new session (no forged
  IDs, no DB writes).
- **Conduit** (`app/`) — native macOS menu-bar app (SwiftUI + AppKit) that
  wraps skill-sharing, chat hand-off and unified history behind a UI. Builds
  with Command Line Tools only (no Xcode); `build.sh` assembles the signed
  `.app`, `package_dmg.sh` produces a distributable DMG.
- **`prototype/index.html`** — high-fidelity interactive HTML prototype
  (墨绿 brand system, dark/light theme, canvas ambience).
- **`docs/V2_CHAT_SYNC_DESIGN.md`** — design notes and the canonical model.
- **CI**: chatsync import/CLI smoke tests + a macOS `swift build` job for the app.
- `.github/` project scaffolding: issue templates (bug report, new-agent /
  path-change), a pull-request template, and an issue-template `config.yml`.
- Continuous integration (`.github/workflows/ci.yml`): validates every
  `SKILL.md` frontmatter and dry-runs the distributor on every push and PR.
- `scripts/validate_skills.py` — checks each `SKILL.md` has a `name:` and
  `description:` in its frontmatter (used by CI and locally).
- `CHANGELOG.md`, `CODE_OF_CONDUCT.md`, and `SECURITY.md`.

### Changed
- README (en + zh) now documents all three layers, with install-from-release
  and build-from-source instructions for the app.
- `.gitignore` hardened: ignores `.workbuddy/` and app build artifacts
  (`.build`, `*.app`, `*.dmg`, `*.icns`) so private/generated files stay local.
- README badges are now **dynamic** (CI status, latest release, license, stars)
  instead of hard-coded static images.


## [0.1.0] — 2026-07-01

First public release. **Install a skill once, use it across every AI coding agent.**

### Added
- **Portable `SKILL.md`** — encodes the correct way to share a skill across
  agents: install into per-agent directories *inside the repo* so it travels
  with Git, and use the right per-tool invocation syntax.
- **`scripts/distribute.py`** — cross-platform fan-out helper (tested: dry-run
  and real distribution both land a `SKILL.md` under each target dir).
- **`docs/INSTALL.md`** — per-tool paths (user + repo scope) with Windows
  equivalents. Verified 2026-07.
- **README** (English + 简体中文) — the "why there is no shared skills
  directory" explainer, a 30-second compatibility table, and a curated
  Related projects list.
- **`CONTRIBUTING.md`** — how to submit path updates (the most valuable PR here).
- **Logo** — SVG icon + wordmark.
- **MIT license.**

### Agents covered
Claude Code · Codex CLI · Cursor · Gemini CLI · Cline

[Unreleased]: https://github.com/BreetyGreen/Myco/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/BreetyGreen/Myco/compare/v0.3.2...v0.4.0
[0.3.2]: https://github.com/BreetyGreen/Myco/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/BreetyGreen/Myco/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/BreetyGreen/Myco/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/BreetyGreen/Myco/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/BreetyGreen/Myco/releases/tag/v0.1.0
