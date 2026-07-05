# Contributing

Thanks for helping keep this project accurate. The **single most valuable**
contribution here is keeping the per-tool skill paths current — they drift fast
as Claude Code, WorkBuddy, Codex CLI, Cursor and Antigravity evolve.

## The kind of PR we want most: path updates

`docs/INSTALL.md` and `skills/multi-agent-skill-sharing/SKILL.md` contain a table
of where each agent discovers skills. If a tool changed its directory, added a
new scope, or you found the docs wrong on your machine — **that's the PR.**

When you submit a path change, please include:

1. **Tool + version** — e.g. `Codex CLI 0.9.x`, `Cursor 1.x`.
2. **OS** — macOS / Linux / Windows.
3. **How you verified** — one of:
   - dropped a skill folder in the path and the agent actually picked it up, or
   - a link to the tool's official docs stating the path.
4. **Date tested** — so the next reader knows how fresh it is.

> We prefer "verified on my machine" over "the docs say so" — docs and reality
> disagree often in this space (Codex's `~/.agents/` vs `~/.codex/skills/` is the
> classic example).

## Quick local check

Test the distributor before and after your change:

```bash
# dry run — prints what would be written, touches nothing
python engine/distribute.py --dry-run

# real run into a throwaway dir
TMP=$(mktemp -d)
python engine/distribute.py --dest "$TMP"
find "$TMP" -name SKILL.md
rm -rf "$TMP"
```

If you edited `distribute.py`, make sure both the dry run and a real run into a
temp dir still land a `SKILL.md` under each target directory.

## Adding a new agent

Adding support for another tool (Windsurf, Aider, Continue, Zed, …)? Great.
Since **v0.3.1 there is a single source of truth**:
[`engine/agents.json`](engine/agents.json). Both the Swift app
(`AgentDetector`) and the Python engine (`distribute.py`) read it, so detection
and skill-distribution can never drift apart. **Adding an agent is one JSON
edit — no recompile, no touching two code paths.**

1. **Add an entry to `engine/agents.json`** — give it an `id`, `display`,
   `initial`, detection `root`/`detail`, a `sessions` block (`jsonl` with
   `dirs`, or `sqlite` with `db` + `query`), and its `skillDir`. That's the
   whole functional change.
2. **Update the human-facing docs so they match** (these are read by people,
   not code):
   - `docs/INSTALL.md` — a section + Windows equivalent
   - `skills/.../SKILL.md` — the compatibility table
   - `README.md` / `README.zh-CN.md` — the 30-second table
3. **Add a CHANGELOG entry** under `[Unreleased]`.

Include your verification notes (see above) in the PR description.

## Style

- Keep prose tight and factual. This is a reference, not a blog post.
- Paths in tables, commands in fenced blocks.
- Cross-platform: every Unix command needs a Windows/PowerShell equivalent.

## Reporting without a PR

No time for a PR? Open an issue with the tool, version, OS, correct path, and
how you verified it. A good issue is almost as useful as a patch here.
