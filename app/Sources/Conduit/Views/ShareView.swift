import SwiftUI

struct ShareView: View {
    @EnvironmentObject var store: AppStore
    @State private var skillIdx = 0
    @State private var targets: [SkillTarget] = []
    @State private var dryRun = true
    @State private var result: String = ""
    @State private var running = false

    var body: some View {
        let p = store.palette
        Group {
            Eyebrow(text: "Skill 共享")
            Text("一次编写，每个 agent 都能用")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(p.text)
            Text("选一个源 skill，扇出到各 agent 的仓库目录；`git commit` 后全团队每个工具都能读到。")
                .font(.system(size: 12)).foregroundColor(p.text2)
                .fixedSize(horizontal: false, vertical: true)

            // 源 skill 选择
            if !store.skills.isEmpty {
                let sk = store.skills[skillIdx % store.skills.count]
                BevelCard(padding: 13) {
                    HStack(spacing: 11) {
                        Image(systemName: "doc.text.fill").font(.system(size: 15))
                            .foregroundColor(p.brand)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 9).fill(p.brandTint))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sk.name).font(.system(size: 13, weight: .semibold))
                                .foregroundColor(p.text)
                            Text(sk.desc).font(.system(size: 11)).foregroundColor(p.text3)
                                .lineLimit(2)
                        }
                        Spacer()
                        if store.skills.count > 1 {
                            Button(action: { withAnimation(.spring1) { skillIdx += 1 } }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13)).foregroundColor(p.text2)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            // 目标勾选
            Eyebrow(text: "扇出到").padding(.top, 2)
            VStack(spacing: 7) {
                ForEach(targets.indices, id: \.self) { i in
                    targetRow(i)
                }
            }

            // dry-run 开关
            Toggle(isOn: $dryRun) {
                HStack(spacing: 6) {
                    Text("预演模式（dry-run）").font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(p.text)
                    Text("只预览路径，不写文件").font(.system(size: 10.5))
                        .foregroundColor(p.text3)
                }
            }
            .toggleStyle(.switch)
            .tint(p.brand2)
            .padding(.vertical, 4)

            PrimaryButton(title: running ? "分发中…" : (dryRun ? "预演分发" : "分发 skill"),
                          icon: "square.stack.3d.up.fill") { distribute() }

            if !result.isEmpty {
                AccentNote {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dryRun ? "预演结果" : "已写入")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(p.brand)
                        Text(result).font(.system(size: 11, design: .monospaced))
                            .foregroundColor(p.text2)
                            .fixedSize(horizontal: false, vertical: true)
                        if !dryRun {
                            Text("别忘了 git commit —— 没进 Git 就不算共享。")
                                .font(.system(size: 11)).foregroundColor(p.warn)
                        }
                    }
                }
            }
        }
        .onAppear { if targets.isEmpty { targets = store.defaultTargets() } }
    }

    private func targetRow(_ i: Int) -> some View {
        let p = store.palette
        let t = targets[i]
        return Button(action: { targets[i].checked.toggle() }) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(t.checked ? p.brand : p.line, lineWidth: 1.4)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(t.checked ? p.brand : .clear))
                        .frame(width: 20, height: 20)
                    if t.checked {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                            .foregroundColor(store.appearance == .dark ? Color(hex: "0B1408") : .white)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(t.label).font(.system(size: 13, weight: .semibold))
                            .foregroundColor(p.text)
                        if t.recommended {
                            Text("推荐").font(.system(size: 9, weight: .bold))
                                .foregroundColor(p.brand)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(p.brandTint))
                        }
                    }
                    Text("<repo>/\(t.dir)/").font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(p.text3)
                }
                Spacer()
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(t.checked ? p.brandTint.opacity(0.5) : p.card2)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(t.checked ? p.brandGlow : p.lineSoft, lineWidth: 0.5)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func distribute() {
        guard !store.skills.isEmpty else { return }
        let sk = store.skills[skillIdx % store.skills.count]
        let selected = targets.filter { $0.checked }.map { $0.id }
        guard !selected.isEmpty else { result = "请至少勾选一个目标 agent。"; return }
        running = true; result = ""
        PythonBridge.shared.distribute(
            src: sk.path,
            dest: PythonBridge.shared.workDir.path,
            agents: selected,
            dryRun: dryRun
        ) { r in
            running = false
            let body = r.stdout.isEmpty ? r.stderr : r.stdout
            result = String(body.suffix(600))
        }
    }
}
