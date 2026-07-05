<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-wordmark-dark.png">
    <img src="assets/logo-wordmark.png" alt="Myco" width="420">
  </picture>
</p>

<h1 align="center">Myco</h1>

<p align="center">
  <em>为你的 AI agent 编织的菌丝网络 —— 一个 Mac App，在你所有编程 agent 之间
  共享技能、接力对话、打通历史。</em>
</p>

<p align="center">
  <a href="https://github.com/BreetyGreen/Myco/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/BreetyGreen/Myco/ci.yml?branch=master&label=CI&color=3B6D11" alt="CI status"></a>
  <a href="https://github.com/BreetyGreen/Myco/releases/latest"><img src="https://img.shields.io/github/v/release/BreetyGreen/Myco?color=639922&label=download" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/BreetyGreen/Myco?color=3B6D11" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-639922" alt="macOS 13+">
  <img src="https://img.shields.io/badge/agents-5%20supported-97C459" alt="5 agents supported">
</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

蘑菇只是果实，真正的生命体是地下的**菌丝网络（mycelium）**—— 一张活的网，把整片森林连在一起，让每棵树共享养分与信号。你的 AI 编程 agent 就是这片森林：**Claude Code**、**Codex CLI**、**Cursor**、**Gemini CLI**、**Cline** —— 每个都很强，却彼此完全隔绝。

**Myco 就是那张菌丝网。** 一个原生 macOS 菜单栏 App，悄悄把你的 agent 连起来，让它们能共享彼此所知：

- 🟢 **共享技能** —— 写一份 `SKILL.md`，铺进每个 agent 的仓库目录，你教会一个工具的技能，其它工具也都能用。
- 🔵 **接力对话** —— 把某个 agent 里的一段对话，接到另一个 agent 里*用它自发的合法新会话*继续（不伪造 ID、不注入假历史）。
- 🟣 **打通历史** —— 把每个 agent 的本地记录读成一份中性、可搜索、可离线浏览与备份的统一时间线。

全部都在菜单栏里完成。不用命令行，无需任何配置。

---

## 安装

<p align="center">
  <a href="https://github.com/BreetyGreen/Myco/releases/latest">
    <img src="https://img.shields.io/badge/⬇%20下载%20Myco-.dmg-639922?style=for-the-badge" alt="下载 Myco">
  </a>
</p>

1. 从[最新 Release](https://github.com/BreetyGreen/Myco/releases/latest) 下载 **`Myco-x.y.z.dmg`**。
2. 打开 DMG，把 **`Myco.app`** 拖进**「应用程序」**。
3. 首次启动：因为 App 是 ad-hoc 签名（未经 Apple 公证），Gatekeeper 会拦一下。**右键点 `Myco.app` → 打开 → 打开**，一次即可。

之后 Myco 就常驻在菜单栏（顶部右侧那个三层叠图标）。点开它，所有功能都在同一个面板里。

> **系统要求：** macOS 13+。仅此而已 —— Myco 完全自包含，用的是 macOS 自带的 `python3`，不需要装任何其它东西。

---

## App 里有什么

Myco 打开是五个 Tab，每个都是一种能力，而不是一个独立工具：

| Tab | 做什么 |
|-----|--------|
| **总览** | 一眼看清这台 Mac 上装了哪些 agent、各自有多少段会话。 |
| **共享** | 选一个技能，勾选要铺给哪些 agent（`.claude` / `.codex` / `.agents` / `.cline`），预览后写入。commit 一下，全团队同步。 |
| **接力** | 挑一段过往对话，打包成可粘贴文本，拿到*另一个* agent 里接着聊。 |
| **历史** | 跨所有已检测 agent 的、合并后可搜索的时间线。 |
| **设置** | 主题、agent 开关、工作目录。 |

一切都是**只读设计**：Myco 绝不写回任何 agent 的存储。agent 的数据库（Cursor / Antigravity 的 SQLite）一律以只读模式打开；接力与归档操作只产出文本。

---

## 为什么会有这个问题（30 秒速览）

如果你在同一个项目里用了不止一个 AI 编程工具，你一定同时撞过这两堵墙：

**技能是隔离的。** 这些 agent 之间根本没有一个"公用的技能目录"，"装一次，所有工具都能看到"字面意义上是不成立的 —— 每个产品从**不同的**仓库目录读技能：

| Agent | 仓库级目录（随 Git 走） | 怎么调用 |
|-------|------------------------|---------|
| **Claude Code** | `.claude/skills/` | 直接提技能名（有些套件会加 `/斜杠命令`） |
| **Codex CLI** | `.agents/skills/` 和/或 `.codex/skills/` | `$skill-name`、`/skills`，或直接提名字 —— **不是** `/design` |
| **Cursor** | `.cursor/rules/`（规则形态） | 规则自动注入；也兼容 `.agents/` |
| **Gemini CLI** | `.agents/skills/` | 在提示词里提名字 |
| **Cline** | `.cline/skills/`、`.clinerules/skills/` 或 `.claude/skills/` | 提名字（实验性开关） |

**会话同样是隔离的。** 每个工具把记录存在各自的地方、用各自的格式 —— 这边 JSONL、那边 SQLite blob —— 你在一个 agent 里积累的上下文，对下一个 agent 完全不可见。

Myco 知道所有这些位置和格式，替你把它们打通。这正是重点：你不该去背这张表 —— App 替你记住。

---

## 面向贡献者 —— 引擎在幕后

Myco 的 UI 只是一层很薄的 SwiftUI 外壳，真正干活的是一个小巧的、**纯 Python 标准库**引擎（在 [`engine/`](engine/) 里），App 通过 `Process` 调用它。你平常根本看不到它 —— 但如果你想改 Myco、从源码构建，或者想脚本化地无头调用这些能力，它都在这儿：

| 引擎模块 | 驱动 |
|----------|------|
| [`engine/distribute.py`](engine/distribute.py) | 技能扇出（共享 Tab） |
| [`engine/sync_chats.py`](engine/sync_chats.py) | 历史聚合（历史 Tab） |
| [`engine/handoff_chat.py`](engine/handoff_chat.py) | 会话接力（接力 Tab） |
| [`engine/chatsync/`](engine/chatsync/) | 规范化消息模型 + 各 agent reader + 导出器 |

从源码构建 App（仅需 Command Line Tools，**无需 Xcode**）：

```bash
cd app
./build.sh              # swift build -c release → 组装自包含的 Myco.app
./package_dmg.sh        # （可选）产出可分发的 .dmg
open Myco.app
```

架构、环境变量开关、源码布局见 [`app/README.md`](app/README.md)。
Myco 随附并用于分发的那份可移植技能在
[`skills/multi-agent-skill-sharing/SKILL.md`](skills/multi-agent-skill-sharing/SKILL.md)，
设计说明在 [`docs/`](docs/)。

---

## 仓库结构

```
multi-agent-skill-sharing/          (即 Myco 项目)
├── README.md
├── LICENSE
├── app/                      # Myco —— SwiftUI 菜单栏 App（就是产品本体）
│   ├── Sources/Myco/         #   原生 UI + PythonBridge
│   ├── build.sh              #   组装自包含的 Myco.app
│   └── package_dmg.sh        #   产出可安装的 .dmg
├── engine/                   # Myco 的内部 Python 引擎（纯标准库）
│   ├── distribute.py         #   技能扇出
│   ├── sync_chats.py         #   历史聚合 → 归档 + HTML
│   ├── handoff_chat.py       #   打包某段对话做合法接力
│   └── chatsync/             #   规范化模型 + reader + 导出器
├── skills/                   # Myco 随附并分发的 SKILL.md 载荷
│   └── multi-agent-skill-sharing/SKILL.md
├── prototype/                # 高保真可交互 HTML 原型
├── assets/                   # 品牌：logo、wordmark、配色
└── docs/                     # 安装说明 + 设计文档
```

---

## 同类项目

Myco 关注的是**把你已经在用的 agent 连起来**，而不是罗列技能。如果你要找的是大量现成技能的合集，下面这些很优秀：

| 项目 | Stars | 是什么 |
|------|-------|--------|
| [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) | 20k+ | 跨 agent 技能目录（Claude、Codex、Gemini、Cursor）—— 最大的精选清单 |
| [openai/skills](https://github.com/openai/skills) | 9k+ | OpenAI 官方的 Codex 技能目录 |
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | 6k+ | Vercel 官方技能 + CLI 工具 |
| [anthropics/skills](https://github.com/anthropics/skills) | — | Anthropic 官方为 Claude Code 出的技能 |
| [agentskills/agentskills](https://github.com/agentskills/agentskills) | 10k+ | 开放的 **SKILL.md** 规范 / 标准 |

> 那些项目告诉你**有哪些**技能可用。Myco 把你真正在用的工具连起来，让一份技能 —— 或一段对话 —— 能在它们之间自由流动。

---

## 提醒

这些工具的技能发现约定**变化很快**。Myco 用到的路径核实于 **2026-07**。如果某个路径不生效，请查阅对应工具自己的文档 —— 也非常欢迎提 PR 帮忙更新。

## 参与贡献

发现了新的 agent、变化了的路径，或者更好的调用技巧？路径更新是这里最有价值的贡献 ——
见 [CONTRIBUTING.md](CONTRIBUTING.md)（需要注明工具版本、操作系统、你是怎么验证的），以及一条本地快速自检命令。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。
