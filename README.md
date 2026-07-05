<p align="center">
  <img src="assets/logo-wordmark.png" alt="multi-agent-skill-sharing" width="420">
</p>

<h1 align="center">multi-agent-skill-sharing</h1>

<p align="center">
  <em>Install a skill <strong>once</strong> and make every AI coding agent on the same repo able to use it.</em>
</p>

<p align="center">
  <a href="https://github.com/BreetyGreen/multi-agent-skill-sharing/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/BreetyGreen/multi-agent-skill-sharing/ci.yml?branch=master&label=CI&color=3B6D11" alt="CI status"></a>
  <a href="https://github.com/BreetyGreen/multi-agent-skill-sharing/releases"><img src="https://img.shields.io/github/v/release/BreetyGreen/multi-agent-skill-sharing?color=639922" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/BreetyGreen/multi-agent-skill-sharing?color=3B6D11" alt="MIT License"></a>
  <a href="https://github.com/BreetyGreen/multi-agent-skill-sharing/stargazers"><img src="https://img.shields.io/github/stars/BreetyGreen/multi-agent-skill-sharing?style=flat&color=97C459" alt="Stars"></a>
  <img src="https://img.shields.io/badge/agents-5%20supported-639922" alt="5 agents supported">
</p>

<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">简体中文</a>
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

It has since grown two more layers that solve the *other* half of the
multi-agent problem — your **conversations** are just as siloed as your skills:

| Layer | What it does | Entry point |
|-------|--------------|-------------|
| **① Share skills** | One `SKILL.md` → every agent's repo dir, then `git commit`. | [`scripts/distribute.py`](scripts/distribute.py) |
| **② Sync & hand off chats** | Read all agents' local histories into one neutral archive; package one chat so another agent can *legitimately* continue it. | [`scripts/sync_chats.py`](scripts/sync_chats.py), [`scripts/handoff_chat.py`](scripts/handoff_chat.py) |
| **③ Conduit menu-bar app** | A native macOS tray app that wraps all of the above behind a UI. | [`app/`](app/) |


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

Preview first (writes nothing), or target only the agents you actually run:

```bash
# see exactly what would be written, without touching disk
python3 .../scripts/distribute.py --src ./skill --dest . --dry-run

# only fan out to Claude Code + Codex, skip the rest
python3 .../scripts/distribute.py --src ./skill --dest . --agents claude,codex
```

Available `--agents` selectors: `claude`, `codex`, `agents`, `cline`
(default: `claude,codex,agents`).

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

## ② Sync & hand off conversations across agents

Skills aren't the only thing that's siloed — your **chat histories** are too.
Each tool keeps its transcripts in its own place and its own format:

| Agent | Where its history lives | Format |
|-------|-------------------------|--------|
| **Claude Code** | `~/.claude/projects/**/*.jsonl` | JSONL |
| **WorkBuddy** | `~/.workbuddy/**` | JSONL |
| **Codex CLI** | `~/.codex/sessions/**/*.jsonl` | JSONL |
| **Cursor** | `state.vscdb` (SQLite) | SQLite blobs |
| **Antigravity** | workspace SQLite stores | SQLite |

Two read-only tools bridge them (both **pure Python stdlib**, nothing to install):

**`sync_chats.py`** — read every agent's local history into one neutral,
searchable archive plus an offline HTML timeline:

```bash
# aggregate all detected agents into ./chat-archive + a merged HTML timeline
python3 scripts/sync_chats.py --out ./chat-archive
```

**`handoff_chat.py`** — package *one* conversation into paste-ready text so a
different agent can continue it in a **legitimately new session** (no forged
IDs, no fake history injection):

```bash
# turn one Codex session into a hand-off block you can paste into Claude Code
python3 scripts/handoff_chat.py --session <id> --to claude
```

Design notes and the canonical message model live in
[`docs/V2_CHAT_SYNC_DESIGN.md`](docs/V2_CHAT_SYNC_DESIGN.md) and
[`scripts/README_chatsync.md`](scripts/README_chatsync.md).

---

## ③ Conduit — the menu-bar app

<p align="center">
  <em>one workspace, every agent</em>
</p>

**Conduit** is a native macOS menu-bar app that wraps all of the above behind a
clean UI — share skills, hand off chats, and browse a unified history without
touching the command line.

- **Native & tiny** — SwiftUI + AppKit (`NSStatusItem` tray + `NSPopover`),
  builds with **Command Line Tools only, no Xcode required**.
- **Read-only by design** — agent detection and history reads never mutate your
  data; SQLite is opened `immutable=1&mode=ro`.
- **Reuses the Python core** — the UI just calls the same
  `distribute.py` / `sync_chats.py` / `handoff_chat.py` scripts via `Process`.

### Install (pre-built)

Download `Conduit-x.y.z.dmg` from the
[Releases page](https://github.com/BreetyGreen/multi-agent-skill-sharing/releases),
open it, and drag **Conduit.app** into **Applications**. It's ad-hoc signed, so
on first launch use **right-click → Open** to get past Gatekeeper.

### Build from source

```bash
cd app
./build.sh              # swift build -c release + assemble Conduit.app + icns + ad-hoc sign
./package_dmg.sh        # (optional) produce a distributable .dmg
open Conduit.app
```

See [`app/README.md`](app/README.md) for the full architecture, the
debug/screenshot env-var switches, and the source layout.

---

## Repository layout

```
multi-agent-skill-sharing/
├── README.md
├── LICENSE
├── skill/
│   └── multi-agent-skill-sharing/
│       └── SKILL.md          # ① the portable skill itself
├── scripts/
│   ├── distribute.py         # ① cross-platform skill fan-out helper
│   ├── sync_chats.py         # ② aggregate all agents' history → archive + HTML
│   ├── handoff_chat.py       # ② package one chat for a legit hand-off
│   └── chatsync/             # ② canonical model + per-agent readers + exporters
├── app/                      # ③ Conduit — SwiftUI menu-bar app (no Xcode needed)
├── prototype/                # ③ high-fidelity interactive HTML prototype
└── docs/
    ├── INSTALL.md            # per-tool install + Windows notes
    └── V2_CHAT_SYNC_DESIGN.md
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
