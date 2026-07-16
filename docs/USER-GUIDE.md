# Myco User Guide (Windows)

> Myco — the mycelial layer for your agents.
> It connects the AI coding assistants installed on your machine
> (Claude Code, WorkBuddy, Codex CLI, Cursor, Antigravity…) into one network:
> **share skills, hand off conversations, unify history** — while staying
> strictly read-only toward every agent's own data.

The macOS build has the same features in menu-bar form. Screenshots below are
from the Windows build. 中文版：[USER-GUIDE.zh-CN.md](USER-GUIDE.zh-CN.md)

---

## Install & launch

1. Grab either from the
   [latest release](https://github.com/BreetyGreen/Myco/releases/latest)
   (the .NET runtime and a Python engine are bundled in both):
   - **`Myco-Setup-x.y.z.exe`** (recommended) — standard wizard: per-user
     install, Start-Menu shortcut, optional start-at-login, uninstall via
     Settings → Apps
   - **`Myco-win-x.y.z.zip`** (portable) — unzip anywhere, double-click
     `Myco.exe`
2. SmartScreen may warn on first run (unsigned): **More info → Run anyway**,
   once.
3. Myco lives in the **system tray** (bottom-right, the stacked-tiles icon):
   - **Left click** — open / dismiss the panel
   - **Right click** — Open · Re-detect · Quit

The panel dismisses itself when you click elsewhere, like the system
calendar flyout.

> Requirements: Windows 10/11. On Win11 the panel gets a native acrylic
> glass backdrop.

---

## Home — your agents at a glance

![Home tab](images/windows-home.png)

The first screen when the panel opens:

| Area | Meaning |
|---|---|
| **Neon-lime hero card** | Total **sessions** available for archiving / handoff, across every installed agent |
| Two small cards | Detected agent count · distributable skill count |
| **AGENTS list** | One row per agent: colored initial badge + data directory + status |
| Bottom cards | Shortcuts into **Share** and **Relay** |

**Status badges:**

- `约 N 段` (≈ N sessions) — installed; count comes from counting `*.jsonl`
  files, hence approximate
- `未安装` (not installed) — no data directory for that agent on this machine
- `结构已变` (layout changed, amber) — the agent is installed but its session
  storage no longer matches what Myco knows (usually a product update).
  Myco says so honestly instead of showing a wrong number.

Detection paths are driven by `engine/agents.json` — adding or fixing an
agent is a one-file edit.

---

## Share — write a skill once, every agent can use it

![Share tab](images/windows-share.png)

Fans a skill (a `SKILL.md` directory) out into each agent's conventional
skill directory; after `git commit`, every tool on the team can read it.

1. **Pick the source skill** — the top card shows the current one (a switch
   button appears when there are several)
2. **Tick the targets** — the list comes from `agents.json`: five agent
   directories (`.claude/skills`, `.codex/skills`, …) plus two generic ones
   (`.agents/skills` — cross-agent, recommended; `.cline/skills`)
3. **Dry-run is on by default** — it only lists the paths that would be
   written, touching nothing. Turn it off and click again to actually write
4. Click **分发 skill** (Distribute); the result card lists what happened

> Don't forget to `git commit` afterwards — a skill that isn't in Git isn't
> shared.

---

## Relay — switch tools, keep the conversation

![Relay tab](images/windows-relay.png)

Packages one conversation from product A as paste-ready text so you can
continue it in product B. No forged session IDs, no writing into any
database — product B continues in its own, legitimately created session.

1. The list shows real sessions from every agent (title · short id · turns ·
   date); pick one
2. Choose a **packaging mode**:
   - `自动` (auto) — decided by conversation length (recommended)
   - `完整` (full) — the whole transcript, most faithful
   - `摘要` (summary) — condensed, for very long chats
   - `近期` (recent) — only the latest exchanges
3. Click **生成接力包** (Build handoff) — the package is written to the output
   directory (`handoff-<agent>-<id>.md`) **and copied to the clipboard**
4. Open the target product, start a new chat, paste, continue

> **Long conversations?** Oversized packages auto-trim to a recap plus key
> turns, but the untrimmed transcript is exported alongside (`-full.md`) and
> named in the package header — a file-capable target agent (Claude Code,
> Codex, …) will read the full history itself and use the inline excerpt as
> a table of contents. Workspace-scoped sessions also carry their project
> path so the target agent reads the repo for code-layer context.

---

## History — a cross-agent chat archive

![History tab](images/windows-history.png)

Aggregates every agent's history into one neutral, searchable, backup-friendly
archive. Click **聚合并生成时间线** (Aggregate & build timeline) and the output
directory gains:

```
Documents/Myco/chat-archive/
├── index.json           # manifest
├── <session>.md/.json   # neutral format any tool can read
└── viewer.html          # single-file offline timeline — double-click to
                         # browse & search (follows OS dark/light, with a
                         # manual toggle that remembers your choice)
```

> The archive contains your private conversations. It is git-ignored by
> default — review before sharing or committing anywhere.

---

## Settings — theme & paths

![Settings tab](images/windows-settings.png)

- **Theme** — dark / light toggle (the sun/moon button in the header does the
  same)
- **Script resources (read-only)** — where the Python engine and bundled
  skills live
- **Output directory (writable)** — handoff packages, archives and
  distributions all land here; defaults to `Documents\Myco`, one click to open
- **Python interpreter** — the one actually in use (full distribution uses the
  bundled `python\python.exe`)
- **Re-detect** — rescan agents after installing a new tool

---

## Privacy promise

- Every agent's local data is accessed **read-only**; SQLite databases are
  opened in read-only mode
- Myco **never writes back** into any agent's storage
- Handoff / archive operations only produce text files, all inside your own
  output directory
- No network upload — everything happens on your machine

---

## FAQ

**Q: "Python not found"?**
The full distribution bundles Python, so this shouldn't happen. On the light
package or from source, install [Python 3](https://www.python.org/downloads/)
or point `MYCO_PYTHON` at an interpreter.

**Q: An agent shows "结构已变" (layout changed)?**
That product moved or reshaped its session storage in an update. Myco reports
it honestly instead of guessing. Please open an issue with the new path —
it's usually a one-line `engine/agents.json` fix.

**Q: Why is the session count approximate?**
For jsonl-based agents the count comes from counting files — fast but not
parsed per file. The Relay list is parsed for real and exact.

**Q: I can't see the glass effect?**
Acrylic shows whatever is *behind* the panel — over a plain background the
blur is featureless by nature. Put a colorful window behind it and it pops.
Windows 10 / older Win11 falls back to an opaque backdrop automatically.

**Q: Can I skip the UI and use the CLI?**
Yes — the engine is a plain CLI (run inside the install directory; use
`python\python.exe` for the bundled interpreter):

```powershell
python engine\agent_status.py            # agent detection overview
python engine\sync_chats.py --dry-run    # preview history aggregation
python engine\handoff_chat.py --list     # list sessions available for handoff
python engine\distribute.py --dry-run    # preview skill distribution
```

---

## Advanced: environment variables

| Variable | Effect |
|---|---|
| `MYCO_REPO` | Override the resource root (point at a source tree during development) |
| `MYCO_WORKDIR` | Override the output directory (default `Documents\Myco`) |
| `MYCO_PYTHON` | Override the Python interpreter |
| `MYCO_PREVIEW=1` | Open the panel as a normal window (screenshots/demos); combine with `MYCO_TAB` |
