# Myco — the mycelial layer for your AI agents

菜单栏 App。像菌丝网络在地下把整片森林连起来一样，Myco 把你所有 AI coding agent 之间的 **技能** 与 **对话** 连成一张共享网络。

- 🟢 **共享技能**：一份 `SKILL.md` 扇出到每个 agent 的仓库目录（`.claude`/`.codex`/`.agents`/`.cline`），`git commit` 后全团队共享。
- 🔵 **接力对话**：把 A 产品的一段对话打包成可粘贴文本，在 B 产品用它自发的合法新会话继续（不伪造 ID）。
- 🟣 **统一历史**：把 5 个 agent 的历史聚合成一份中性、可搜索、可备份的归档 + 离线 HTML 时间线。

纯菜单栏应用（`LSUIElement`），墨绿品牌 + 深浅双主题。UI 用 SwiftUI 原生绘制，能力内核由 Myco 内置的 Python 引擎（`engine/`）驱动，用户无需关心。

> 这是 **面向贡献者** 的构建说明。只想用 Myco 的用户请直接从 [Releases](https://github.com/BreetyGreen/Myco/releases) 下载 DMG，把 `Myco.app` 拖进「应用程序」即可，无需任何命令行。

## 技术形态

- **前端**：SwiftUI + AppKit（`NSStatusItem` 托盘 + `NSPopover` 承载）。无需 Xcode，仅 Command Line Tools 即可编译。
- **引擎**：`PythonBridge` 用 `Process` 调用内置的 Python 引擎（`engine/distribute.py`、`sync_chats.py`、`handoff_chat.py`），捕获 stdout/stderr。安装版里引擎随 bundle 打进 `Contents/Resources/`，完全自包含。
- **只读**：agent 检测与历史读取全程只读；SQLite 以 `immutable=1&mode=ro` 打开。

## 构建 & 运行

```bash
cd app
./build.sh                       # swift build -c release + 组装自包含 Myco.app
open Myco.app                    # 图标出现在顶部菜单栏右侧，点击弹面板
```

安装版 `Myco.app` 是自包含的：引擎已打进 bundle，双击即用，不依赖任何环境变量。开发时若想让 App 指向源码树里的引擎，可设 `MYCO_REPO`：

```bash
MYCO_REPO="$(cd .. && pwd)" open Myco.app
```

### 调试 / 截图开关（可选）

| 环境变量 | 作用 |
|---|---|
| `MYCO_PREVIEW=1` | 用普通窗口显示面板（而非菜单栏），便于演示/截图 |
| `MYCO_TAB=home\|share\|relay\|history\|settings` | 预览时指定初始 tab |
| `MYCO_SHOT=/path.png` | 渲染完成后把面板自渲染成 PNG |
| `MYCO_SHOT_QUIT=1` | 截图后自动退出 |

## 目录

```
app/
  Package.swift
  build.sh                    # 组装自包含 Myco.app（+ icns + ad-hoc 签名）
  package_dmg.sh              # 打包可拖拽安装的 Myco-x.y.z.dmg
  Sources/Myco/
    MycoApp.swift             # 入口：NSStatusItem + NSPopover（+ 预览/截图模式）
    Theme.swift               # 墨绿品牌调色板（深浅双主题）+ 弹簧动画常量
    Models.swift              # Agent / Session / Skill / SkillTarget
    AgentDetector.swift       # 只读扫描本机 5 个 agent 安装状态与会话数
    PythonBridge.swift        # Process 调用内置引擎 distribute/sync_chats/handoff
    AppStore.swift            # ObservableObject 全局状态中枢
    TrayIcon.swift            # 三层叠 chip 托盘图标（模板图）
    Components/UIKit.swift     # BrandMark / Eyebrow / BevelCard / 按钮 / LiveDot / AccentNote
    Views/
      RootView.swift          # popover 容器：品牌头 + 内容 + 底部 Tab
      HomeView.swift          # 总览：统计卡 + agent 列表 + CTA
      ShareView.swift         # 技能共享（调 distribute.py）
      OtherViews.swift        # 接力 / 历史 / 设置
```
