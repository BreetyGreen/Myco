# chatsync (v2) — 跨产品聊天记录同步

> v1（`distribute.py`）解决「一个 skill 如何被多个 agent 复用」；
> **v2 解决「多个 agent 的聊天记录如何汇总成一份统一、可检索、可随 Git 走的归档」。**
> 设计依据见 [`../docs/V2_CHAT_SYNC_DESIGN.md`](../docs/V2_CHAT_SYNC_DESIGN.md)。

## 一句话

把 Claude Code / WorkBuddy / Codex CLI / Cursor / Antigravity 的历史对话，
**只读**解析 → 归一到 Canonical 中间格式 → 导出成 Markdown（人读）+ JSON（机读），
并可生成一个离线 HTML 时间线做合并浏览与全文搜索。

## 只读安全承诺

**本工具永不写入任何 agent 的存储。** Cursor / Antigravity 的 SQLite 库一律以
`file:...?mode=ro`（immutable 只读）打开——它们是运行中应用持锁的不透明 blob，
外部写入会导致整库损坏、应用打不开。因此 v2 **只做读取归档，不做回写注入**
（原因详见设计文档第 5 节）。

## 快速开始

```bash
# 导出全部可用来源到 ./chat-archive
python3 engine/sync_chats.py

# 只选部分来源、指定输出目录
python3 engine/sync_chats.py --agents claude,workbuddy,codex --out ./chat-archive

# 预览将导出什么，不落盘
python3 engine/sync_chats.py --dry-run

# 只导出某日期之后的会话
python3 engine/sync_chats.py --since 2026-06-01

# 额外生成离线 HTML 时间线（默认最多内嵌 300 个最新会话）
python3 engine/sync_chats.py --html --html-max 300
```

纯标准库，跨平台（macOS / Linux / Windows），无需安装任何依赖。

## 支持的来源（本机自动探测）

| agent | 存储 | 形态 | 说明 |
|-------|------|------|------|
| `claude` | `~/.claude/projects/**/*.jsonl` | 一会话一 JSONL | 结构最干净 |
| `workbuddy` | `~/.workbuddy/projects/**/*.jsonl` | 一会话一 JSONL | 与 Claude 近似同构，共用一个 reader |
| `codex` | `~/.codex/sessions/**/*.jsonl` | 事件流 | 自动去重（同一轮 message + user_message 双写）、去脚手架 |
| `cursor` | `.../Cursor/.../globalStorage/state.vscdb` | SQLite KV | 只读；正文在 `cursorDiskKV` 的 `bubbleId:` |
| `antigravity` | `.../Antigravity/.../state.vscdb` | SQLite KV | 只读；正文落点随版本待确认，优雅降级 |

## 输出结构

```
chat-archive/
├── index.json                       # 全量清单（manifest）
├── viewer.html                      # 离线合并时间线（--html 时生成）
├── claude/2026-06-30/<slug>-<id>.md # 每会话一份 Markdown + 一份 JSON
├── workbuddy/…
├── codex/…
└── cursor/…
```

- **Markdown**：人可读，含元信息 + 有损转换说明 + 逐条消息（工具调用/推理折叠展示）。
- **JSON**：机器可读，完整 Canonical dump（`schema_version` 1.0）。
- **viewer.html**：单文件、离线、双击即开；左侧会话列表（按来源过滤），右侧正文，顶部全文搜索。

## Canonical 中间格式

所有来源归一到统一模型（`chatsync/canonical.py`）：

```
CanonicalSession { session_id, source_agent, source_ref, project,
                   created_at, updated_at, title, messages[], lossy_notes[] }
CanonicalMessage { role(user|assistant|system|tool), text, timestamp, blocks[], meta }
Block            { kind(text|tool_use|tool_result|reasoning), text, raw }
```

- `text` 是最小公分母（人读 + 全文检索），所有来源都能填。
- `blocks` 保留结构化信息（工具调用、推理轨迹）。
- `lossy_notes` **诚实记录**本次转换丢了什么，不假装无损。

## 会话接力（handoff）——把 A 产品的对话搬到 B 产品「接着聊」

`sync_chats.py` 解决「统一查看历史」；`handoff_chat.py` 解决另一个需求：
**我在产品 A（如 Codex）里的某个会话，想换到产品 B（如 WorkBuddy）里接着往下聊。**

它的做法是把 A 的完整对话打包成**一段可粘贴的文本**（前情说明 + 对话正文 + 接力指令），
你在 B 里**新开一个会话**、粘贴、发送——B 读完前情就能无缝续聊。

> **不伪造 ID，不写任何数据库。** B 里那条会话是 B 自己现发的合法新会话，
> 我们只「读 A、产出文本」。这跟「把 A 的旧记录硬塞进 B 的库里冒充 B 的历史」
> （脏、会损坏运行库）是两回事——后者明确不做。

```bash
# 1) 先列出候选会话（可按来源/关键词过滤）
python3 engine/handoff_chat.py --list
python3 engine/handoff_chat.py --list --agents codex --search 简历

# 2) 选一个（用 SHORTID / 完整 id / 标题子串），默认「既存 .md 文件又进剪贴板」
python3 engine/handoff_chat.py --session 019f078f
python3 engine/handoff_chat.py --session "简历" --agents codex

# 3) 打开 B（如 WorkBuddy）→ 新开对话 → 粘贴(Cmd/Ctrl+V) → 发送 → 继续聊
```

打包模式（`--mode`）：

| 模式 | 行为 | 适用 |
|------|------|------|
| `auto`（默认） | 全文能装下就全文；超出字符预算自动降级为「前情提要 + 首尾关键轮次」 | **推荐**，兼顾完整与上下文长度 |
| `full` | 全文逐字，工具调用压成一行（可能很长，粘贴到 B 可能被截断） | 短/中会话要一字不落 |
| `summary` | 始终「前情提要 + 关键轮次」，最短 | 只要前情、不要全文 |
| `recent` | 「前情提要 + 最近若干轮原文」，从最新一轮往前装满字符预算（至少 2 轮） | 只想从上次停下的地方接着做 |

其它常用参数：

- `--max-chars N`：auto 降级的字符预算（默认 48000，模型无关的保守值）。
- `--no-file` / `--no-clip`：分别关闭「写文件」「进剪贴板」（默认两者都开）。
- `--out path.md`：指定输出文件路径。
- `--print`：把完整交接包也打到标准输出（便于管道/预览）。

**去噪**：用户消息里的 `<system-reminder>`、`<additional_data>`，以及 Codex 每轮
注入的 `<turn_aborted>`、`<codex_internal_context>`、`<skill>`、"Continue working
toward the active thread goal…" 等**运行时脚手架**都会被剥掉，交接包里只保留
你**真正说过的话**和助手的实质回复。

**唯一诚实的限制**：模型有上下文长度上限。超长会话（如上千轮）用 `auto` 会自动
降级为摘要 + 关键轮次，并在输出里明确标注「已降级」以及被省略的轮数；完整正文
仍然保存在 `sync_chats.py` 导出的 `.md` / `.json` 里，随时可查。

## ⚠️ 隐私提示

生成的 `chat-archive/` 包含你**真实的历史对话内容**（可能含代码、密钥片段、私人信息）。
在 `git commit` 或分享前请自行审阅。如果不希望进版本库，把 `chat-archive/` 加进
`.gitignore` 即可——工具本身（`engine/`）不含任何个人数据，可放心提交。
`handoff_chat.py` 生成的 `handoff-*.md` 同理，是你的私人对话，默认已 git-ignore。

## 模块结构

```
engine/
├── sync_chats.py               # CLI 入口（归档 + 离线时间线）
├── handoff_chat.py             # CLI 入口（会话接力：A→B 续聊）
└── chatsync/
    ├── canonical.py            # Canonical 数据模型 + 序列化 + 标题/正文去噪
    ├── base.py                 # Reader 抽象基类
    ├── utils.py                # 时间归一 / 路径解码 / slug / 文本抽取 / 剪贴板
    ├── exporter.py             # Canonical → Markdown + JSON + manifest
    ├── handoff.py              # Canonical → 会话接力包（full/summary/auto/recent）
    ├── html_viewer.py          # Canonical → 单文件离线 HTML 时间线
    └── readers/
        ├── jsonl_reader.py     # Claude + WorkBuddy（同构，共用）
        ├── codex_reader.py     # Codex 事件流（去重 + 去脚手架）
        └── sqlite_reader.py    # Cursor + Antigravity（SQLite 只读）
```
