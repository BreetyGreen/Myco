# v0.1.0 — First release

**Install a skill once, use it across every AI coding agent.**

The first public release of `multi-agent-skill-sharing`: a portable `SKILL.md`
plus a cross-platform distributor that makes a single skill genuinely shared and
switchable across Claude Code, Codex CLI, Cursor, Gemini CLI, and Cline.

## What's inside

- **Portable `SKILL.md`** — encodes the correct way to share a skill across
  agents: install into per-agent directories *inside the repo* so it travels
  with Git, and use the right per-tool invocation syntax.
- **`scripts/distribute.py`** — cross-platform fan-out helper (tested: dry-run +
  real distribution both land a `SKILL.md` under each target dir).
- **`docs/INSTALL.md`** — per-tool paths (user + repo scope) with Windows
  equivalents. Verified 2026-07.
- **README** — the "why there is no shared skills directory" explainer, a
  30-second compatibility table, and a curated Related projects list.
- **`CONTRIBUTING.md`** — how to submit path updates (the most valuable PR here).
- **Logo** — SVG icon + wordmark.
- **MIT licensed.**

## Agents covered

Claude Code · Codex CLI · Cursor · Gemini CLI · Cline

## Known caveat

Skill-discovery paths across these tools change fast. Everything here was
verified 2026-07; if a path drifts, PRs are very welcome (see CONTRIBUTING.md).
