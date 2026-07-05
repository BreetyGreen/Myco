# Conduit — one workspace, every agent

菜单栏 App，把你所有 AI coding agent 之间的 **skill 与会话** 连成一条通路。

- 🟢 **共享**：一份 `SKILL.md` 扇出到每个 agent 的仓库目录（`.claude`/`.codex`/`.agents`/`.cline`），`git commit` 后全团队共享。
- 🔵 **接力**：把 A 产品的一段对话打包成可粘贴文本，在 B 产品用它自发的合法新会话继续（不伪造 ID）。
- 🟣 **历史**：把 5 个 agent 的历史聚合成一份中性、可搜索、可备份的归档 + 离线 HTML 时间线。

纯菜单栏应用（`LSUIElement`），墨绿品牌 + 深浅双主题。UI 用 SwiftUI 原生绘制，功能内核复用仓库里已有的 Python 脚本（`scripts/distribute.py`、`sync_chats.py`、`handoff_chat.py`）。

## 技术形态

- **前端**：SwiftUI + AppKit（`NSStatusItem` 托盘 + `NSPopover` 承载）。无需 Xcode，仅 Command Line Tools 即可编译。
- **桥接**：`PythonBridge` 用 `Process` 调用现有 Python CLI，捕获 stdout/stderr。
- **只读**：agent 检测与历史读取全程只读；SQLite 以 `immutable=1&mode=ro` 打开。

## 构建 & 运行

```bash
cd app
./build.sh                       # swift build -c release + 组装 Conduit.app
# 正常菜单栏模式（图标出现在顶部菜单栏右侧，点击弹面板）
CONDUIT_REPO="$(cd .. && pwd)" open Conduit.app
```

App 通过环境变量 `CONDUIT_REPO` 找到仓库根（内含 `scripts/`）。未设置时会从 bundle 位置向上探测，或回退到开发路径。

### 调试 / 截图开关（可选）

| 环境变量 | 作用 |
|---|---|
| `CONDUIT_PREVIEW=1` | 用普通窗口显示面板（而非菜单栏），便于演示/截图 |
| `CONDUIT_TAB=home\|share\|relay\|history\|settings` | 预览时指定初始 tab |
| `CONDUIT_SHOT=/path.png` | 渲染完成后把面板自渲染成 PNG |
| `CONDUIT_SHOT_QUIT=1` | 截图后自动退出 |

## 目录

```
app/
  Package.swift
  build.sh
  Sources/Conduit/
    ConduitApp.swift        # 入口：NSStatusItem + NSPopover（+ 预览/截图模式）
    Theme.swift             # 墨绿品牌调色板（深浅双主题）+ 弹簧动画常量
    Models.swift            # Agent / Session / Skill / SkillTarget
    AgentDetector.swift     # 只读扫描本机 5 个 agent 安装状态与会话数
    PythonBridge.swift      # Process 调用 distribute/sync_chats/handoff
    AppStore.swift          # ObservableObject 全局状态中枢
    TrayIcon.swift          # 三层叠 chip 托盘图标（模板图）
    Components/UIKit.swift   # BrandMark / Eyebrow / BevelCard / 按钮 / LiveDot / AccentNote
    Views/
      RootView.swift        # popover 容器：品牌头 + 内容 + 底部 Tab
      HomeView.swift        # 总览：统计卡 + agent 列表 + CTA
      ShareView.swift       # Skill 共享（调 distribute.py）
      OtherViews.swift      # 接力 / 历史 / 设置
```
