# Installation — per tool

Skill-discovery paths change fast. **Verified 2026-07.** If something doesn't
resolve, check the tool's own docs.

Each skill must live **exactly one directory deep** (agents don't recurse):
`.../skills/<skill-name>/SKILL.md`.

---

## Claude Code

| Scope | Path |
|-------|------|
| User | `~/.claude/skills/<skill>/SKILL.md` |
| Repo | `<repo>/.claude/skills/<skill>/SKILL.md` |

Invoke by mentioning the skill by name in chat. Some suites layer `/slash`
commands on top (e.g. gstack), but that's an add-on, not the base mechanism.

---

## WorkBuddy

| Scope | Path |
|-------|------|
| User | `~/.workbuddy/skills/<skill>/SKILL.md` |
| Repo | `<repo>/.workbuddy/skills/<skill>/SKILL.md` |

Invoke by mentioning the skill by name in chat (same convention as Claude Code).
Sessions live under `~/.workbuddy/projects/` as one JSONL file per conversation.

---

## Codex CLI

Two conventions exist in the wild — install into **both** to be safe.

| Scope | Path (official) | Path (seen in practice) |
|-------|-----------------|-------------------------|
| User | `~/.agents/skills/` | `~/.codex/skills/` |
| Repo | `<repo>/.agents/skills/` | `<repo>/.codex/skills/` |
| Admin | `/etc/codex/skills/` | — |

You can also override with an env var:

```bash
export CODEX_SKILLS_PATH=/path/to/your/skills
```

**Invocation:** `$skill-name`, the `/skills` picker, or just mention it in the
prompt. **Do not** expect a `/design`-style command — those are Claude Code
suite extensions, not Codex skills. Codex's old `~/.codex/prompts/` custom
prompts are deprecated.

Codex also reads `AGENTS.md` at the repo root on every run — put routing notes
there.

---

## Cursor

Cursor uses a **rules** format (`.mdc` files), not `SKILL.md`.

| Scope | Path |
|-------|------|
| Repo | `<repo>/.cursor/rules/` |

Rules auto-inject based on their frontmatter globs. Cursor also tolerates
`.agents/` skills in some setups.

---

## Antigravity

Antigravity is VS Code–based (like Cursor), so it has no official `SKILL.md`
mechanism yet. The **convention** Myco uses:

| Scope | Path |
|-------|------|
| Repo | `<repo>/.antigravity/skills/<skill>/SKILL.md` |

Sessions are stored in a SQLite KV database
(`~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb`),
which Myco opens **read-only** to count/read conversations. Treat the skill
path as unverified-by-vendor — mention the skill by name and confirm the tool
picks it up.

---

## Gemini CLI

| Scope | Path |
|-------|------|
| Repo | `<repo>/.agents/skills/` |

Auto-discovered; mention the skill in the prompt.

---

## Cline

| Scope | Path |
|-------|------|
| Repo | `.cline/skills/`, `.clinerules/skills/`, or `.claude/skills/` |
| User | `~/.cline/skills/` |

Triple repo lookup is deliberate — drop a Claude Code skill folder in and it
works. Gated behind an experimental Settings toggle.

---

## Windows path equivalents

| Unix | Windows |
|------|---------|
| `~/.claude/skills/` | `%USERPROFILE%\.claude\skills\` |
| `~/.codex/skills/` | `%USERPROFILE%\.codex\skills\` |
| `~/.agents/skills/` | `%USERPROFILE%\.agents\skills\` |

PowerShell distribution:

```powershell
cd <repo>
New-Item -ItemType Directory -Force .\.claude\skills, .\.agents\skills, .\.codex\skills | Out-Null
Copy-Item -Recurse -Force .\.claude\skills\* .\.agents\skills\
Copy-Item -Recurse -Force .\.claude\skills\* .\.codex\skills\
```

---

## Don't forget

The new directories are **untracked** until you commit them. It isn't shared
until it's in Git:

```bash
git add .claude/skills .agents/skills .codex/skills AGENTS.md
git commit -m "chore: share skills across AI agents"
```
