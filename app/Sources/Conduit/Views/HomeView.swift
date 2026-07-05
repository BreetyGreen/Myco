import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        let p = store.palette
        Group {
            Eyebrow(text: "本机概览")
            Text("检测到 ")
                .font(.system(size: 13)).foregroundColor(p.text2)
            + Text("\(store.installedCount) 个 agent")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(p.text)
            + Text("，共 ").font(.system(size: 13)).foregroundColor(p.text2)
            + Text("\(store.totalSessions) 段会话")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(p.text)
            + Text(" 可归档与接力。").font(.system(size: 13)).foregroundColor(p.text2)

            // 统计卡
            HStack(spacing: 9) {
                stat("\(store.installedCount)", "已装 agent", green: true)
                stat("\(store.totalSessions)", "会话总数")
                stat("\(store.skills.count)", "可分发 skill")
            }

            // agent 列表
            Eyebrow(text: "AGENTS").padding(.top, 4)
            VStack(spacing: 7) {
                ForEach(store.agents) { a in AgentRow(agent: a) }
            }

            // 两个 CTA
            HStack(spacing: 9) {
                ctaCard("square.stack.3d.up", "共享 skill", "扇出到各 agent") { store.tab = .share }
                ctaCard("arrow.left.arrow.right", "会话接力", "换个工具接着聊") { store.tab = .relay }
            }
            .padding(.top, 2)

            AccentNote {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield").font(.system(size: 12))
                            .foregroundColor(p.brand)
                        Text("隐私承诺").font(.system(size: 12, weight: .semibold))
                            .foregroundColor(p.brand)
                    }
                    Text("全程只读本地会话；SQLite 一律以只读模式打开，绝不写回任何 agent 运行库；接力/归档只产出文本，目标会话使用其产品自发的合法新 ID，不伪造。")
                        .font(.system(size: 11.5)).foregroundColor(p.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func stat(_ n: String, _ k: String, green: Bool = false) -> some View {
        let p = store.palette
        return BevelCard(padding: 11) {
            VStack(alignment: .leading, spacing: 5) {
                Text(n).font(.system(size: 24, weight: .bold)).monospacedDigit()
                    .foregroundColor(green ? p.brand : p.text)
                Text(k).font(.system(size: 10.5, weight: .medium)).foregroundColor(p.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ctaCard(_ icon: String, _ title: String, _ sub: String,
                         _ act: @escaping () -> Void) -> some View {
        let p = store.palette
        return Button(action: { withAnimation(.spring1, act) }) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon).font(.system(size: 15))
                    .foregroundColor(p.brand)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 8).fill(p.brandTint))
                    .padding(.bottom, 9)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(p.text)
                Text(sub).font(.system(size: 10.5)).foregroundColor(p.text3).padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(RoundedRectangle(cornerRadius: 13).fill(p.card)
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(p.line, lineWidth: 0.5)))
        }
        .buttonStyle(.plain)
    }
}

struct AgentRow: View {
    let agent: Agent
    @EnvironmentObject var store: AppStore
    var body: some View {
        let p = store.palette
        HStack(spacing: 11) {
            Text(agent.id.initial)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9).fill(p.agentColor(agent.id)))
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.display).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(p.text)
                Text(agent.detail).font(.system(size: 11, design: .monospaced))
                    .foregroundColor(p.text3)
            }
            Spacer()
            HStack(spacing: 6) {
                LiveDot(live: agent.installed)
                Text(agent.installed ? "\(agent.sessionCount) 段" : "未安装")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(agent.installed ? p.brand : p.text3)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(p.card2)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(p.lineSoft, lineWidth: 0.5)))
    }
}
