<p align="center">
  <img src="assets/logo-wordmark.svg" alt="multi-agent-skill-sharing" width="420">
</p>

<h1 align="center">multi-agent-skill-sharing</h1>

<p align="center">
  <em>Install a skill <strong>once</strong> and make every AI coding agent on the same repo able to use it.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-3B6D11" alt="MIT License">
  <img src="https://img.shields.io/badge/agents-5%20supported-639922" alt="5 agents supported">
  <img src="https://img.shields.io/badge/verified-2026--07-97C459" alt="verified 2026-07">
</p>

If you run more than one AI coding tool on the same project — say **Claude Code**,
**Codex CLI**, and **Cursor** — you've probably hit this wall:

- You install a skill and only *one* tool can find it.
- You try `/design` in Codex like you do in Claude Code, and nothing happens.
- You put the skill in `~/.claude/skills/`, switch machines, and it's gone.

The uncomfortable truth: **there is no shared skills directory across agents.**
"Install once, everything sees it" is literally false. Each product reads skills
from a *different* directory, and each has a *different* invocation syntax.

This repo is a portable **`SKILL.md`** (plus a helper script) that encodes the
correct way to make a skill genuinely shared and switchable across tools:

1. Install it into **per-agent directories inside the repository**, so it
   travels with Git.
2. Document the **per-tool invocation syntax** so people actually use it right.

---

## Why it's tricky (the 30-second version)

| Agent | Repo-level dir (travels with Git) | How you invoke it |
|-------|-----------------------------------|-------------------|
| **Claude Code** | `.claude/skills/` | mention the skill by name (some suites add `/slash`) |
| **Codex CLI** | `.agents/skills/` and/or `.codex/skills/` | `$skill-name`, `/skills`, or name it — **not** `/design` |
| **Cursor** | `.cursor/rules/` (rules format) | rules auto-inject; also tolerates `.agents/` |
| **Gemini CLI** | `.agents/skills/` | name it in the prompt |
| **Cline** | `.cline/skills/`, `.clinerules/skills/`, or `.claude/skills/` | name it (experimental toggle) |

> 💡 `.agents/` is emerging as the **cross-agent standard** repo path — Codex,
> Gemini CLI, and Cursor all accept it. If you can only keep one path, that's
> the safest bet.

Full details, pitfalls, and step-by-step instructions live in
[`skill/multi-agent-skill-sharing/SKILL.md`](skill/multi-agent-skill-sharing/SKILL.md).

---

## Install *this* skill (self-demonstrating)

This skill practises what it preaches — here's how to make it available to your
own agents.

### Option A — one agent, quick try

Copy the skill folder into whichever agent you use:

```bash
# Claude Code (user-level)
cp -R skill/multi-agent-skill-sharing ~/.claude/skills/

# Codex CLI (user-level)
cp -R skill/multi-agent-skill-sharing ~/.codex/skills/
```

### Option B — share it across all agents on a project (recommended)

From inside your target project, run the bundled distributor. It fans the skill
out into every agent's repo-level directory and is cross-platform:

```bash
# from your project root
python3 /path/to/multi-agent-skill-sharing/scripts/distribute.py \
  --src /path/to/multi-agent-skill-sharing/skill \
  --dest .
```

Then commit the new `.claude/skills`, `.agents/skills`, `.codex/skills`
directories so the skill travels with Git.

See [`docs/INSTALL.md`](docs/INSTALL.md) for per-tool details and Windows steps.

---

## How to use it, once installed

Just describe your situation to your agent, e.g.:

> "I use Codex and Claude Code on this repo — make this skill usable in both."

or ask it the question that triggers the skill:

> "Why can only Claude Code use this skill?"

The skill walks the agent through detecting your tools, distributing the skill
into the right directories, writing routing notes into `AGENTS.md`, and
reminding you to commit.

---

## Repository layout

```
multi-agent-skill-sharing/
├── README.md
├── LICENSE
├── skill/
│   └── multi-agent-skill-sharing/
│       └── SKILL.md          # the portable skill itself
├── scripts/
│   └── distribute.py         # cross-platform fan-out helper
└── docs/
    └── INSTALL.md            # per-tool install + Windows notes
```

## Related projects

This repo is deliberately **narrow**: it teaches the *mechanics* of making one
skill work across agents. If you're looking for large catalogs of ready-made
skills, these excellent projects are worth your time:

| Project | Stars | What it is |
|---------|-------|------------|
| [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) | 20k+ | Cross-agent catalog (Claude, Codex, Gemini, Cursor) — the biggest curated list |
| [openai/skills](https://github.com/openai/skills) | 9k+ | OpenAI's official Codex skills directory |
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | 6k+ | Vercel's official skills + CLI tooling |
| [anthropics/skills](https://github.com/anthropics/skills) | — | Anthropic's official skills for Claude Code |
| [agentskills/agentskills](https://github.com/agentskills/agentskills) | 10k+ | The open **SKILL.md** specification / standard |
| [JackyST0/awesome-agent-skills](https://github.com/JackyST0/awesome-agent-skills) | — | Cross-platform list with a one-click installer + online search |

> Those tell you **what** skills exist. This repo tells you **how** to make any
> one of them shared and switchable across the tools you actually run.

---

## Caveat

Skill-discovery conventions across these tools **change quickly**. The paths
here were verified **2026-07**. If a path doesn't resolve, check the tool's own
docs — and PRs to keep the table current are very welcome.

## Contributing

Found a new agent, a changed path, or a better invocation trick? Path updates
are the most valuable contribution here — see [CONTRIBUTING.md](CONTRIBUTING.md)
for what to include (tool version, OS, how you verified) and a quick local check.

## License

MIT — see [LICENSE](LICENSE).
