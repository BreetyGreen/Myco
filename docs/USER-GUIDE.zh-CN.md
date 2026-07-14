# Myco 使用指南（Windows 版）

> Myco —— the mycelial layer for your agents。
> 把你机器上各自为政的 AI 编程助手（Claude Code、WorkBuddy、Codex CLI、
> Cursor、Antigravity…）连成一张网：**技能共享、会话接力、历史归档**，
> 全程只读它们的数据，绝不写回。

macOS 版的安装与功能一致（菜单栏形态），本文以 Windows 版截图为准。

---

## 安装与启动

1. 从 [最新 Release](https://github.com/BreetyGreen/Myco/releases/latest)
   下载 **`Myco-win-x.y.z.zip`**。
2. 解压到任意位置，双击 **`Myco.exe`** —— 绿色免安装，.NET 运行时和
   Python 引擎都在包里，无需装任何依赖。
3. Myco 出现在**任务栏右下角托盘**（三层叠方块图标）：
   - **左键**：打开 / 收起主面板
   - **右键**：打开 Myco · 重新检测 · 退出

面板在点击其他地方时会自动收起，就像系统的日历弹窗一样。

> 系统要求：Windows 10/11（Win11 下面板带原生亚克力玻璃效果）。

---

## 总览 —— 本机 agent 一目了然

![总览页](images/windows-home.png)

打开面板的第一屏：

| 区域 | 说明 |
|---|---|
| **荧光绿大卡** | 全机可归档/接力的**会话总数**，跨所有已装 agent |
| 右侧两张小卡 | 已检测到的 agent 数量、当前可分发的 skill 数量 |
| **AGENTS 列表** | 每个 agent 一行：彩色字母徽标 + 数据目录 + 状态 |
| 底部两张卡片 | 快捷入口：跳转到「共享」/「接力」 |

**状态徽标含义：**

- `约 N 段` —— 已安装，检测到约 N 段会话（数 `*.jsonl` 文件得出，是近似值，所以带"约"）
- `未安装` —— 这台机器上没有该 agent 的数据目录
- `结构已变`（黄字）—— agent 装了，但它的会话存储结构和 Myco 认识的不一样
  （通常是该产品改版了），Myco 会如实提示而不是给出错误数字

agent 的检测路径由 `engine/agents.json` 驱动，新增/修正 agent 只需改这一个文件。

---

## 共享 —— 一次编写，每个 agent 都能用

![共享页](images/windows-share.png)

把一份 skill（`SKILL.md` 及其目录）扇出到各个 agent 约定的技能目录，
`git commit` 之后全团队每个工具都能读到。

**操作步骤：**

1. **选源 skill**：顶部卡片显示当前选中的 skill（多于一个时右侧有切换按钮）
2. **勾选目标**：列表来自 `agents.json`，包含五个 agent 目录
   （`.claude/skills`、`.codex/skills`…）和两个通用目录
   （`.agents/skills` 跨 agent 通用 · 推荐，`.cline/skills`）
3. **预演模式（dry-run）**：默认开启——只列出会写哪些路径，不动任何文件。
   确认无误后关掉开关再点一次，才会真正写入
4. 点 **分发 skill**，结果卡片会列出每个目标的写入情况

> 写入后别忘了 `git commit` —— 没进 Git 就不算共享。

---

## 接力 —— 换个工具，接着聊

![接力页](images/windows-relay.png)

把 A 产品的一段对话打包成可粘贴的文本，在 B 产品里开个新会话继续聊。
不伪造会话 ID、不写回任何库——目标产品用它自己合法新建的会话接续。

**操作步骤：**

1. 列表里是全机所有 agent 的真实会话（标题 · 短 ID · 轮数 · 日期），点选一段
2. 选**打包模式**：
   - `自动` —— 根据会话长度自动决定（推荐）
   - `完整` —— 全文打包，最忠实但最长
   - `摘要` —— 压缩成摘要，适合很长的会话
   - `近期` —— 只带最近的往来
3. 点 **生成接力包** —— 接力包写入输出目录（`handoff-<agent>-<id>.md`），
   **同时已复制到剪贴板**
4. 到目标产品里新建会话，直接粘贴，接着聊

---

## 历史 —— 跨 agent 的聊天档案馆

![历史页](images/windows-history.png)

把所有 agent 的历史聚合成一份中性、可搜索、可备份的归档。

点 **聚合并生成时间线**，Myco 会在输出目录生成：

```
Documents/Myco/chat-archive/
├── index.json          # 归档清单
├── <每段会话>.md/.json  # 中性格式，任何工具都能读
└── viewer.html         # 单文件离线时间线，双击浏览器打开即可搜索浏览
                        #（跟随系统深浅色，右上角 🌓 可手动切换并记住）
```

> 归档里是你的私人对话。它默认被 `.gitignore` 排除——分享或提交前请自查。

---

## 设置 —— 主题与路径

![设置页](images/windows-settings.png)

- **外观主题**：深色 / 浅色一键切换（右上角太阳/月亮按钮同样有效）
- **脚本资源（只读）**：Python 引擎和随附 skill 所在位置
- **输出目录（可写）**：接力包、归档、分发都落在这里，默认
  `文档\Myco`，可点「打开输出目录」直达
- **Python 解释器**：当前实际使用的 Python（完整分发包用内嵌的
  `python\python.exe`，也支持系统 Python）
- **重新检测**：重新扫描本机 agent（装了新工具后点一下）

---

## 隐私承诺

- 全程**只读**各 agent 的本地数据；SQLite 数据库一律以只读模式打开
- **绝不写回**任何 agent 的运行库
- 接力/归档只产出文本文件，全部落在你自己的输出目录里
- 无网络上传——所有处理都在本机完成

---

## 常见问题

**Q：提示"未找到 Python"？**
完整分发包自带 Python，不会遇到。如果你用的是轻量包或源码运行，
装一个 [Python 3](https://www.python.org/downloads/) 即可；也可以用
环境变量 `MYCO_PYTHON` 指定解释器路径。

**Q：某个 agent 显示"结构已变"？**
说明该产品更新后换了会话存储位置/格式。Myco 选择如实提示而不是硬猜。
欢迎到仓库提 issue（附上新路径），通常改一行 `engine/agents.json` 就能修好。

**Q：会话数为什么带"约"？**
jsonl 类 agent 的会话数是数文件数得出的近似值，快但不逐文件解析；
接力列表里的才是逐段解析的精确数据。

**Q：面板的玻璃效果怎么看不出来？**
亚克力玻璃显示的是面板**背后**的内容——背景是纯色时糊出来自然是一片素色。
在面板后面放个彩色窗口或换张有内容的壁纸就明显了。Win10 或旧版
Win11 上会自动回退为不透明底色。

**Q：可以只用命令行、不开界面吗？**
可以，引擎本身就是 CLI（在安装目录运行，`python` 换成 `python\python.exe` 即为内嵌解释器）：

```powershell
python engine\agent_status.py            # agent 检测概览
python engine\sync_chats.py --dry-run    # 历史聚合预演
python engine\handoff_chat.py --list     # 列出可接力的会话
python engine\distribute.py --dry-run    # skill 分发预演
```

---

## 高级：环境变量

| 变量 | 作用 |
|---|---|
| `MYCO_REPO` | 覆盖资源根（开发时指向源码树） |
| `MYCO_WORKDIR` | 覆盖输出目录（默认 `文档\Myco`） |
| `MYCO_PYTHON` | 覆盖 Python 解释器路径 |
| `MYCO_PREVIEW=1` | 以普通窗口打开面板（截图/演示用），配合 `MYCO_TAB` 指定初始页 |
