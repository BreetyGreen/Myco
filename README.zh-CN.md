<p align="center">
  <img src="assets/logo-wordmark.png" alt="multi-agent-skill-sharing" width="420">
</p>

<h1 align="center">multi-agent-skill-sharing</h1>

<p align="center">
  <em>一次安装，让同一个项目里的<strong>每一个</strong> AI 编程助手都能用上同一份技能。</em>
</p>

<p align="center">
  <a href="https://github.com/BreetyGreen/multi-agent-skill-sharing/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/BreetyGreen/multi-agent-skill-sharing/ci.yml?branch=master&label=CI&color=3B6D11" alt="CI status"></a>
  <a href="https://github.com/BreetyGreen/multi-agent-skill-sharing/releases"><img src="https://img.shields.io/github/v/release/BreetyGreen/multi-agent-skill-sharing?color=639922" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/BreetyGreen/multi-agent-skill-sharing?color=3B6D11" alt="MIT License"></a>
  <a href="https://github.com/BreetyGreen/multi-agent-skill-sharing/stargazers"><img src="https://img.shields.io/github/stars/BreetyGreen/multi-agent-skill-sharing?style=flat&color=97C459" alt="Stars"></a>
  <img src="https://img.shields.io/badge/agents-5%20supported-639922" alt="5 agents supported">
</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

如果你在同一个项目里同时用了不止一个 AI 编程工具 —— 比如 **Claude Code**、**Codex CLI**、**Cursor** —— 你大概率撞过这几堵墙：

- 装了一个技能，结果只有**一个**工具能找到它。
- 你在 Codex 里像在 Claude Code 里那样敲 `/design`，结果什么都没发生。
- 你把技能放进 `~/.claude/skills/`，换了台电脑，它就没了。

一个不太舒服的真相：**这些 agent 之间根本没有一个"公用的技能目录"。**"装一次，所有工具都能看到"这句话，字面意义上是**不成立**的。每个产品从**不同的目录**读技能，而且各自的**调用语法也不一样**。

这个仓库提供一份可移植的 **`SKILL.md`**（外加一个辅助脚本），把"如何让一份技能真正做到跨工具共享、随时切换使用"的正确做法编码了进去：

1. 把它安装到**项目仓库内部的、各 agent 各自的目录**里，这样它就能随 Git 一起走。
2. 把**每个工具各自的调用语法**写清楚，这样大家才会用对。

后来它又长出了两层，去解决多 agent 问题的*另一半* —— 你的**会话**和你的技能一样，也是各自为政、彼此隔离的：

| 能力层 | 做什么 | 入口 |
|--------|--------|------|
| **① 共享技能** | 一份 `SKILL.md` → 铺进每个 agent 的仓库目录，`git commit` 后全队共享。 | [`scripts/distribute.py`](scripts/distribute.py) |
| **② 同步 & 接力会话** | 把各 agent 的本地历史读成一份中性归档；把某一段对话打包，让另一个 agent *合法地*接着聊下去。 | [`scripts/sync_chats.py`](scripts/sync_chats.py)、[`scripts/handoff_chat.py`](scripts/handoff_chat.py) |
| **③ Conduit 菜单栏 App** | 一个原生 macOS 托盘应用，把以上全部能力包进一个 UI 里。 | [`app/`](app/) |


---

## 为什么这事儿这么绕（30 秒速览）

| Agent | 仓库级目录（随 Git 走） | 怎么调用 |
|-------|------------------------|---------|
| **Claude Code** | `.claude/skills/` | 直接提技能名（有些套件会加 `/斜杠命令`） |
| **Codex CLI** | `.agents/skills/` 和/或 `.codex/skills/` | `$skill-name`、`/skills`，或直接提名字 —— **不是** `/design` |
| **Cursor** | `.cursor/rules/`（规则形态） | 规则自动注入；也兼容 `.agents/` |
| **Gemini CLI** | `.agents/skills/` | 在提示词里提名字 |
| **Cline** | `.cline/skills/`、`.clinerules/skills/` 或 `.claude/skills/` | 提名字（实验性开关） |

> 💡 `.agents/` 正在成为**跨 agent 的通用约定**目录 —— Codex、Gemini CLI、Cursor 都认它。如果你只能保留一个路径，选它最稳。

完整细节、坑和分步说明都在
[`skill/multi-agent-skill-sharing/SKILL.md`](skill/multi-agent-skill-sharing/SKILL.md)。

---

## 安装*这个*技能（自我示范）

这个技能自己就践行了它宣扬的做法 —— 下面是把它装到你自己的 agent 里的方法。

### 方式 A —— 单个 agent，快速试用

把技能文件夹复制到你在用的那个 agent 目录：

```bash
# Claude Code（用户级）
cp -R skill/multi-agent-skill-sharing ~/.claude/skills/

# Codex CLI（用户级）
cp -R skill/multi-agent-skill-sharing ~/.codex/skills/
```

### 方式 B —— 让它在一个项目的所有 agent 间共享（推荐）

在你的目标项目里，运行自带的分发脚本。它会把技能铺到每个 agent 的仓库级目录，并且是跨平台的：

```bash
# 在你的项目根目录下运行
python3 /path/to/multi-agent-skill-sharing/scripts/distribute.py \
  --src /path/to/multi-agent-skill-sharing/skill \
  --dest .
```

可以先预览（不写入任何文件），或只分发给你实际在用的 agent：

```bash
# 只打印将要写入的内容，不动磁盘
python3 .../scripts/distribute.py --src ./skill --dest . --dry-run

# 只铺给 Claude Code + Codex，跳过其余
python3 .../scripts/distribute.py --src ./skill --dest . --agents claude,codex
```

`--agents` 可选值：`claude`、`codex`、`agents`、`cline`
（默认：`claude,codex,agents`）。

然后把新生成的 `.claude/skills`、`.agents/skills`、`.codex/skills`
目录提交进 Git，技能就能随仓库一起走了。

逐个工具的细节和 Windows 步骤见 [`docs/INSTALL.md`](docs/INSTALL.md)。

---

## 装好之后怎么用

直接把你的情况描述给 agent，比如：

> "我在这个仓库里同时用 Codex 和 Claude Code —— 让这个技能两边都能用。"

或者直接问那个能触发技能的问题：

> "为什么只有 Claude Code 能用这个技能？"

技能会引导 agent 走完：检测你在用哪些工具 → 把技能分发到正确的目录 → 往 `AGENTS.md` 里写路由说明 → 提醒你 commit。

---

## ② 跨 agent 同步 & 接力会话

被隔离的不只是技能 —— 你的**聊天历史**也一样。每个工具都把自己的记录存在各自的地方、用各自的格式：

| Agent | 历史存放位置 | 格式 |
|-------|-------------|------|
| **Claude Code** | `~/.claude/projects/**/*.jsonl` | JSONL |
| **WorkBuddy** | `~/.workbuddy/**` | JSONL |
| **Codex CLI** | `~/.codex/sessions/**/*.jsonl` | JSONL |
| **Cursor** | `state.vscdb`（SQLite） | SQLite blob |
| **Antigravity** | 工作区 SQLite 存储 | SQLite |

两个**只读**工具把它们打通（都是**纯 Python 标准库**，零依赖）：

**`sync_chats.py`** —— 把每个 agent 的本地历史读成一份中性、可搜索的归档，外加一份离线 HTML 时间线：

```bash
# 把检测到的所有 agent 聚合进 ./chat-archive + 一份合并 HTML 时间线
python3 scripts/sync_chats.py --out ./chat-archive
```

**`handoff_chat.py`** —— 把*某一段*对话打包成可直接粘贴的文本，让另一个 agent 在一个**合法的新会话**里接着聊（不伪造 ID、不注入假历史）：

```bash
# 把某个 Codex 会话变成一段可粘进 Claude Code 的接力文本
python3 scripts/handoff_chat.py --session <id> --to claude
```

设计说明与规范化消息模型见
[`docs/V2_CHAT_SYNC_DESIGN.md`](docs/V2_CHAT_SYNC_DESIGN.md) 和
[`scripts/README_chatsync.md`](scripts/README_chatsync.md)。

---

## ③ Conduit —— 菜单栏 App

<p align="center">
  <em>one workspace, every agent</em>
</p>

**Conduit** 是一个原生 macOS 菜单栏应用，把上面所有能力包进一个清爽的 UI —— 共享技能、接力会话、浏览统一历史，全程不用碰命令行。

- **原生、极小** —— SwiftUI + AppKit（`NSStatusItem` 托盘 + `NSPopover`），**仅用 Command Line Tools 就能编译，无需 Xcode**。
- **只读设计** —— agent 检测与历史读取绝不改动你的数据；SQLite 以 `immutable=1&mode=ro` 打开。
- **复用 Python 内核** —— UI 只是通过 `Process` 调用同一批 `distribute.py` / `sync_chats.py` / `handoff_chat.py` 脚本。

### 安装（预编译版）

从 [Releases 页面](https://github.com/BreetyGreen/multi-agent-skill-sharing/releases) 下载 `Conduit-x.y.z.dmg`，打开后把 **Conduit.app** 拖进 **Applications**。它是 ad-hoc 签名的，首次启动请用**右键 → 打开**绕过 Gatekeeper。

### 从源码构建

```bash
cd app
./build.sh              # swift build -c release + 组装 Conduit.app + icns + ad-hoc 签名
./package_dmg.sh        # （可选）产出可分发的 .dmg
open Conduit.app
```

完整架构、调试/截图环境变量开关、源码布局见 [`app/README.md`](app/README.md)。

---

## 仓库结构

```
multi-agent-skill-sharing/
├── README.md
├── LICENSE
├── skill/
│   └── multi-agent-skill-sharing/
│       └── SKILL.md          # ① 可移植的技能本体
├── scripts/
│   ├── distribute.py         # ① 跨平台技能分发脚本
│   ├── sync_chats.py         # ② 聚合各 agent 历史 → 归档 + HTML
│   ├── handoff_chat.py       # ② 打包某段对话做合法接力
│   └── chatsync/             # ② 规范化模型 + 各 agent reader + 导出器
├── app/                      # ③ Conduit —— SwiftUI 菜单栏 App（无需 Xcode）
├── prototype/                # ③ 高保真可交互 HTML 原型
└── docs/
    ├── INSTALL.md            # 逐工具安装 + Windows 说明
    └── V2_CHAT_SYNC_DESIGN.md
```


## 同类项目

这个仓库刻意做得很**窄**：它只讲"如何让一份技能在多个 agent 间生效"这套机制。如果你要找的是大量现成技能的目录合集，下面这些优秀项目值得一看：

| 项目 | Stars | 是什么 |
|------|-------|--------|
| [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) | 20k+ | 跨 agent 技能目录（Claude、Codex、Gemini、Cursor）—— 最大的精选清单 |
| [openai/skills](https://github.com/openai/skills) | 9k+ | OpenAI 官方的 Codex 技能目录 |
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | 6k+ | Vercel 官方技能 + CLI 工具 |
| [anthropics/skills](https://github.com/anthropics/skills) | — | Anthropic 官方为 Claude Code 出的技能 |
| [agentskills/agentskills](https://github.com/agentskills/agentskills) | 10k+ | 开放的 **SKILL.md** 规范 / 标准 |
| [JackyST0/awesome-agent-skills](https://github.com/JackyST0/awesome-agent-skills) | — | 跨平台清单，带一键安装 + 在线搜索 |

> 那些项目告诉你**有哪些**技能可用。这个仓库告诉你**如何**让其中任何一个，在你真正在用的那些工具之间共享、随时切换。

---

## 提醒

这些工具的技能发现约定**变化很快**。这里的路径核实于 **2026-07**。如果某个路径不生效，请查阅对应工具自己的文档 —— 也非常欢迎提 PR 帮忙更新这张表。

## 参与贡献

发现了新的 agent、变化了的路径，或者更好的调用技巧？路径更新是这里最有价值的贡献 ——
见 [CONTRIBUTING.md](CONTRIBUTING.md)（需要注明工具版本、操作系统、你是怎么验证的），以及一条本地快速自检命令。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。
