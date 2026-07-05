# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/BreetyGreen/multi-agent-skill-sharing/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/BreetyGreen/multi-agent-skill-sharing/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/BreetyGreen/multi-agent-skill-sharing/releases/tag/v0.1.0
