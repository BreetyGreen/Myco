# Myco Windows 版设计

日期：2026-07-14 · 状态：已批准（方案 A，用户全权委托细节决策）

## 目标

全功能对标 macOS 版 v0.3.x：系统托盘图标 + 弹出面板，五个 tab（总览 / 共享 /
接力 / 历史 / 设置），复用同一份 Python 引擎与 `engine/agents.json` 注册表。
macOS 版行为零改动。

## 背景与约束

- `engine/` 是纯 Python 标准库，天然跨平台；`claude` / `workbuddy` / `codex`
  的 `~/.xxx` 路径在 Windows 上原样可用（`expanduser` 展开）。
- Cursor / Antigravity 在 Windows 的数据在 `%APPDATA%`（`~/AppData/Roaming`），
  与 macOS 的 `~/Library/Application Support` 不同。
- macOS 外壳统计 SQLite 会话用 `/usr/bin/sqlite3` CLI；Windows 没有，但内嵌
  Python 的 stdlib `sqlite3` 可以只读打开。
- Windows 不自带 Python → 分发时内嵌 python.org 官方 embeddable 包（~11MB）。
- 工具链：.NET 8 SDK（对标 macOS 版"只需 CLT、不需要 Xcode"的轻量哲学）。

## 方案选型（已定：A）

- **A（选定）**：单 .NET 8 项目同时启用 `UseWPF` + `UseWindowsForms`。
  托盘用 WinForms 内置 `NotifyIcon`（零 NuGet 依赖），面板用 WPF 无边框深色
  窗口。`dotnet publish` 出自包含单文件 exe。
- B：纯 WinForms —— 托盘最简单，但复刻深色卡片 UI 需大量 owner-draw，放弃。
- C：WinUI 3 —— 工具链/打包最重，托盘反而无内置支持，放弃。

## 架构

```
app-windows/
  Myco.csproj          net8.0-windows, UseWPF + UseWindowsForms, 0 NuGet 依赖
  App.xaml(.cs)        入口：无主窗口，初始化托盘 + AppStore
  TrayIcon.cs          NotifyIcon（三层叠 chip 图标，GDI+ 绘制）+ 右键退出菜单
  PopupWindow.xaml(.cs) 396x640 无边框圆角面板，贴托盘弹出，失焦即隐藏
  Theme.cs             调色板（逐色对齐 app/Sources/Myco/Theme.swift，深/浅两套）
  Models.cs            Agent / Session / ShareableSkill / SkillTarget
  AppStore.cs          全局状态（INotifyPropertyChanged）：agents/skills/sessions
  PythonBridge.cs      资源根定位 + workDir + Python 定位 + 引擎调用封装
  Views/               HomeView / ShareView / RelayView / HistoryView / SettingsView
                       （WPF UserControl，底部 tab 切换）
  build.ps1            发布脚本（见"打包"）
```

### 检测逻辑下沉到引擎（与 macOS 的差异点）

macOS 在 Swift 里原生实现 agent 检测；Windows 版不复刻这套 C# 逻辑，而是新增
**`engine/agent_status.py --json`**：读 `agents.json`、按平台合并路径覆盖、
递归数 `*.jsonl`、用 stdlib `sqlite3`（`file:...?immutable=1&mode=ro`）只读
计数，输出 JSON。C# 只调用并渲染。理由：

1. Windows 没有 sqlite3 CLI，Python stdlib 是现成的只读实现；
2. 检测逻辑单一实现，未来 macOS 也可迁移过来；
3. CLI 用户白赚一个 `python engine/agent_status.py` 状态命令。

### agents.json 平台差分

每个 agent 增加**可选** `"windows": { root/detail/sessions }` 覆盖块，基础键
保持 macOS 值。合并规则：Windows 平台上浅合并覆盖同名键，其他平台忽略。
Swift 端不读取该键 → macOS 零改动、完全向后兼容。只有 cursor / antigravity
需要覆盖（`~/AppData/Roaming/...`）；claude / workbuddy / codex 天然跨平台。

`chatsync/readers/sqlite_reader.py` 的硬编码默认路径同步改为按 `sys.platform`
选择（darwin → `~/Library/Application Support/...`，win32 → `~/AppData/Roaming/...`）。

### PythonBridge（C#）

- 资源根查找顺序 = macOS 版：`MYCO_REPO` 环境变量 → exe 同目录（安装版：
  engine/ 与 exe 平级）→ 从 exe 位置向上搜 8 层找 `engine/distribute.py`
  （源码树运行）→ 当前目录兜底。
- workDir：`MYCO_WORKDIR` → `~/Documents/Myco`，首次自动创建。
- Python 查找顺序：`MYCO_PYTHON` → 随包 `python/python.exe`（embeddable）→
  `py -3` → PATH 上的 `python`。
- 调用时设 `PYTHONPATH=<资源根>/engine`、`PYTHONIOENCODING=utf-8`、
  `PYTHONUTF8=1`（防 GBK 控制台编码毁掉 CJK 输出），`CreateNoWindow = true`
  （防每次调用闪黑框）。

## 数据流

与 macOS 相同：UI 事件 → PythonBridge 异步起 `python engine/xxx.py` 进程 →
捕获 stdout/stderr → 解析（`--json` 的走 System.Text.Json）→ 更新 AppStore →
数据绑定刷新 UI。全程只读 agent 存储；产出物只写 workDir。

## UI 对齐清单（逐页对照 macOS 版）

- 头部：BrandMark（三层 chip）+ "myco" 字标 + 副标语 + 主题切换按钮
- 总览：统计三卡（已装 agent / 会话总数 / 可分发 skill）、agent 列表
  （字母标 + LiveDot + "约 N 段 / 未安装 / 结构已变"）、两张 CTA 卡、隐私承诺块
- 共享：源 skill 卡（读 skills/*/SKILL.md frontmatter）、目标勾选列表
  （agents.json 驱动 + extraSkillTargets）、dry-run 开关、结果卡 + git 提醒
- 接力：会话列表（handoff_chat.py --list --json）→ 选中后模式胶囊
  （auto/full/summary/recent）→ 生成接力包（写 workDir + 剪贴板）
- 历史：已装 agent 会话概览 + "聚合并生成时间线"（sync_chats.py --html）
- 设置：主题切换、资源根/输出目录展示、重新检测、打开输出目录、版本落款
- 字体：Segoe UI 正文 / Consolas 等宽；圆角、间距、三级文字色对齐 Theme.swift
- 不复刻毛玻璃材质（DWM acrylic 兼容性波折多），用等价纯色渐变背景

## 错误处理

- 找不到 Python：面板顶部横幅提示 + 设置页给出指引（装 Python 或用完整分发包）
- 引擎非零退出：结果卡片显示 stderr 尾部（对齐 macOS 版 suffix 行为）
- `--list --json` 解析失败：会话列表显示空态"未检测到会话"
- agent root 在但结构变了：黄字"结构已变"（数据来自 agent_status.py）

## 打包（build.ps1）

1. `dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true`
2. 组装 `Myco-win/`：`Myco.exe` + `engine/`（排除 __pycache__）+ `skills/`
3. 下载并缓存 python-3.12.x embeddable zip → 解压为 `Myco-win/python/`
4. `Compress-Archive` 出 `Myco-win-<version>.zip`（绿色免安装，双击 exe 即用）

## 测试与验证

- 引擎侧（本机真实数据：claude/workbuddy/codex 均已安装）：
  `agent_status.py --json`、`handoff_chat.py --list --json`、
  `sync_chats.py --dry-run`、`distribute.py --dry-run` 全部跑通且输出正确
- 应用侧：`dotnet build` 零警告；启动后托盘图标出现；面板五页可交互；
  分发 dry-run / 会话列表 / 聚合 dry-run 走通真实引擎
- 回归：agents.json 加 `windows` 键后，macOS Swift 解析不受影响（键被忽略）

## 明确不做（YAGNI）

- 不做 MSI/安装器（绿色 zip 即可）、不做代码签名、不做开机自启
- 不做 Linux（另一个话题）
- 不改 macOS 版任何行为
