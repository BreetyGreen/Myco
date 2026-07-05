import SwiftUI
import AppKit

struct RelayView: View {
    @EnvironmentObject var store: AppStore
    @State private var picked: Session?
    @State private var mode = "auto"
    @State private var result = ""
    @State private var running = false

    let modes: [(String, String)] = [
        ("auto", "自动"), ("full", "完整"), ("summary", "摘要"), ("recent", "近期")
    ]

    var body: some View {
        let p = store.palette
        Group {
            Eyebrow(text: "会话接力")
            Text("换个工具，接着聊")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(p.text)
            Text("把 A 产品的一段对话打包成可粘贴文本，在 B 产品用它自发的合法新会话继续——不伪造 ID、不写回任何库。")
                .font(.system(size: 12)).foregroundColor(p.text2)
                .fixedSize(horizontal: false, vertical: true)

            if let s = picked {
                // 已选会话 + 模式 + 生成
                BevelCard(padding: 13) {
                    HStack(spacing: 11) {
                        Text(s.agent.initial).font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white).frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(p.agentColor(s.agent)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).font(.system(size: 13, weight: .semibold))
                                .foregroundColor(p.text)
                            Text("\(s.agent.display) · \(s.id) · \(s.rounds) 轮")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(p.text3)
                        }
                        Spacer()
                        Button(action: { withAnimation(.spring1) { picked = nil; result = "" } }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(p.text3)
                        }.buttonStyle(.plain)
                    }
                }

                Eyebrow(text: "打包模式").padding(.top, 2)
                HStack(spacing: 7) {
                    ForEach(modes, id: \.0) { m in
                        let on = mode == m.0
                        Button(action: { withAnimation(.spring1) { mode = m.0 } }) {
                            Text(m.1).font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(on ? p.brand : p.text2)
                                .padding(.horizontal, 11).padding(.vertical, 6)
                                .background(Capsule().fill(on ? p.brandTint : p.card2)
                                    .overlay(Capsule().strokeBorder(on ? p.brandGlow : p.lineSoft, lineWidth: 0.5)))
                        }.buttonStyle(.plain)
                    }
                }

                PrimaryButton(title: running ? "生成中…" : "生成接力包",
                              icon: "arrow.left.arrow.right") { generate(s) }

                if !result.isEmpty {
                    AccentNote {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("接力包已生成").font(.system(size: 12, weight: .semibold))
                                .foregroundColor(p.brand)
                            Text(result).font(.system(size: 11, design: .monospaced))
                                .foregroundColor(p.text2).lineLimit(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                // 会话列表
                Eyebrow(text: "选择要接力的会话").padding(.top, 2)
                VStack(spacing: 7) {
                    ForEach(store.sessions) { s in
                        Button(action: { withAnimation(.spring1) { picked = s } }) {
                            sessionRow(s)
                        }.buttonStyle(.plain)
                    }
                    if store.sessions.isEmpty {
                        Text("未检测到会话").font(.system(size: 12)).foregroundColor(p.text3)
                            .padding(.vertical, 20)
                    }
                }
            }
        }
    }

    private func sessionRow(_ s: Session) -> some View {
        let p = store.palette
        return HStack(spacing: 11) {
            Text(s.agent.initial).font(.system(size: 13, weight: .heavy))
                .foregroundColor(.white).frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(p.agentColor(s.agent)))
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(p.text).lineLimit(1)
                Text("\(s.id) · \(s.rounds) 轮 · \(s.updated)")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(p.text3)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12))
                .foregroundColor(p.text3)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 12).fill(p.card2)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(p.lineSoft, lineWidth: 0.5)))
        .contentShape(Rectangle())
    }

    private func generate(_ s: Session) {
        running = true; result = ""
        let out = PythonBridge.shared.workDir
            .appendingPathComponent("handoff-\(s.agent.rawValue)-\(s.id).md").path
        PythonBridge.shared.handoffBuild(session: s.id, mode: mode, out: out) { r in
            running = false
            if r.ok {
                result = "已写入 handoff-\(s.agent.rawValue)-\(s.id).md（并复制到剪贴板）。粘贴到目标产品的新会话即可继续。"
            } else {
                result = (r.stderr.isEmpty ? r.stdout : r.stderr).suffix(400).description
            }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var running = false
    @State private var result = ""

    var body: some View {
        let p = store.palette
        Group {
            Eyebrow(text: "历史浏览")
            Text("跨 agent 聊天记录聚合")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(p.text)
            Text("把所有 agent 的历史聚合成一份中性、可搜索、可备份的归档，并生成离线 HTML 时间线。全程只读。")
                .font(.system(size: 12)).foregroundColor(p.text2)
                .fixedSize(horizontal: false, vertical: true)

            // 各 agent 会话概览
            VStack(spacing: 7) {
                ForEach(store.agents.filter { $0.installed }) { a in
                    HStack(spacing: 11) {
                        Text(a.id.initial).font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white).frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 7).fill(p.agentColor(a.id)))
                        Text(a.display).font(.system(size: 13, weight: .medium))
                            .foregroundColor(p.text)
                        Spacer()
                        Text("\(a.sessionCount)")
                            .font(.system(size: 14, weight: .bold)).monospacedDigit()
                            .foregroundColor(p.brand)
                        Text("段").font(.system(size: 11)).foregroundColor(p.text3)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 11).fill(p.card2))
                }
            }

            PrimaryButton(title: running ? "聚合中…" : "聚合并生成时间线",
                          icon: "clock.arrow.circlepath") { sync() }

            if !result.isEmpty {
                AccentNote {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("归档完成").font(.system(size: 12, weight: .semibold))
                            .foregroundColor(p.brand)
                        Text(result).font(.system(size: 11, design: .monospaced))
                            .foregroundColor(p.text2).lineLimit(8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func sync() {
        running = true; result = ""
        let agents = store.installed.map { $0.id.rawValue }
        let out = PythonBridge.shared.workDir.appendingPathComponent("chat-archive").path
        PythonBridge.shared.syncChats(agents: agents, out: out, html: true) { r in
            running = false
            result = String((r.stdout.isEmpty ? r.stderr : r.stdout).suffix(600))
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        let p = store.palette
        Group {
            Eyebrow(text: "设置")

            BevelCard(padding: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("外观主题").font(.system(size: 13, weight: .semibold))
                            .foregroundColor(p.text)
                        Text(store.appearance == .dark ? "深色" : "浅色")
                            .font(.system(size: 11)).foregroundColor(p.text3)
                    }
                    Spacer()
                    Button(action: { store.toggleTheme() }) {
                        HStack(spacing: 6) {
                            Image(systemName: store.appearance == .dark ? "moon.fill" : "sun.max.fill")
                            Text(store.appearance == .dark ? "深色" : "浅色")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(p.brand)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(p.brandTint))
                    }.buttonStyle(.plain)
                }
            }

            BevelCard(padding: 13) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("脚本资源（只读）").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(p.text)
                    Text(PythonBridge.shared.resourceRoot.path)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(p.text3)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider().overlay(p.lineSoft)
                    Text("输出目录（接力包 / 归档 / 分发）").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(p.text)
                    Text(PythonBridge.shared.workDir.path)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(p.text3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button(action: { store.refresh() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("重新检测").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(p.text)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(p.card2)
                                .overlay(Capsule().strokeBorder(p.line, lineWidth: 0.5)))
                        }.buttonStyle(.plain)
                        Button(action: {
                            NSWorkspace.shared.open(PythonBridge.shared.workDir)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                Text("打开输出目录").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(p.text)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(p.card2)
                                .overlay(Capsule().strokeBorder(p.line, lineWidth: 0.5)))
                        }.buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 9) {
                BrandMark(size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Conduit").font(.system(size: 12, weight: .semibold))
                        .foregroundColor(p.text)
                    Text("one workspace, every agent · v0.1")
                        .font(.system(size: 10)).foregroundColor(p.text3)
                }
            }
            .padding(.top, 4)
        }
    }
}
