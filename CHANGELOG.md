# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `.github/` project scaffolding: issue templates (bug report, new-agent /
  path-change), a pull-request template, and an issue-template `config.yml`.
- Continuous integration (`.github/workflows/ci.yml`): validates every
  `SKILL.md` frontmatter and dry-runs the distributor on every push and PR.
- `scripts/validate_skills.py` — checks each `SKILL.md` has a `name:` and
  `description:` in its frontmatter (used by CI and locally).
- `CHANGELOG.md`, `CODE_OF_CONDUCT.md`, and `SECURITY.md`.

### Changed
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

[Unreleased]: https://github.com/BreetyGreen/multi-agent-skill-sharing/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/BreetyGreen/multi-agent-skill-sharing/releases/tag/v0.1.0
