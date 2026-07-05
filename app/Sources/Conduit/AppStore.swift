import SwiftUI
import Combine

/// 全局状态中枢：主题、tab、检测到的 agent、可分发 skill、会话列表、运行日志。
final class AppStore: ObservableObject {
    @Published var appearance: Appearance = .dark
    @Published var tab: Tab = .home
    @Published var agents: [Agent] = []
    @Published var skills: [ShareableSkill] = []
    @Published var sessions: [Session] = []
    @Published var busy = false
    @Published var lastLog: String = ""

    var palette: Palette { Palette(appearance: appearance) }

    enum Tab: String, CaseIterable { case home, share, relay, history, settings }

    // 检测到并安装的 agent
    var installed: [Agent] { agents.filter { $0.installed } }
    var totalSessions: Int { agents.reduce(0) { $0 + $1.sessionCount } }
    var installedCount: Int { installed.count }

    func toggleTheme() {
        withAnimation(.springSoft) {
            appearance = (appearance == .dark ? .light : .dark)
        }
    }

    /// 异步检测本机 agent + 加载可分发 skill（演示用真实存在的 skill 名）。
    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let detected = AgentDetector.detectAll()
            let skills = Self.loadShareableSkills()
            let sess = Self.demoSessions(from: detected)
            DispatchQueue.main.async {
                self.agents = detected
                self.skills = skills
                self.sessions = sess
            }
        }
    }

    /// 从仓库 skill/ 目录读取可分发的 SKILL.md（真实存在的）。
    static func loadShareableSkills() -> [ShareableSkill] {
        let root = PythonBridge.shared.resourceRoot.appendingPathComponent("skill")
        var out: [ShareableSkill] = []
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            for dir in items where (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                let md = dir.appendingPathComponent("SKILL.md")
                guard fm.fileExists(atPath: md.path) else { continue }
                let text = (try? String(contentsOf: md, encoding: .utf8)) ?? ""
                let name = frontmatter(text, "name") ?? dir.lastPathComponent
                let desc = frontmatter(text, "description") ?? "（无描述）"
                out.append(ShareableSkill(id: dir.lastPathComponent, name: name,
                                          desc: String(desc.prefix(90)),
                                          path: dir.path))
            }
        }
        if out.isEmpty {
            out = [ShareableSkill(id: "multi-agent-skill-sharing",
                                  name: "multi-agent-skill-sharing",
                                  desc: "把一份 skill 扇出到每个 agent 的仓库目录。",
                                  path: root.appendingPathComponent("multi-agent-skill-sharing").path)]
        }
        return out
    }

    private static func frontmatter(_ text: String, _ key: String) -> String? {
        for line in text.split(separator: "\n").prefix(20) {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("\(key):") {
                return l.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return nil
    }

    /// 概览用的会话样本（真实数据请走 handoffList；这里给检测到的 agent 生成占位标题）。
    static func demoSessions(from agents: [Agent]) -> [Session] {
        var out: [Session] = []
        let samples = [
            ("019f078f", "修图买表工作流梳理", 101),
            ("a03294d4", "菜单栏 App 原型设计", 48),
            ("7c2b91de", "会话接力方案讨论", 33),
            ("3e5f10ab", "skill 分发脚本重构", 27),
        ]
        for (i, a) in agents.filter({ $0.installed }).enumerated() {
            let s = samples[i % samples.count]
            out.append(Session(id: s.0, agent: a.id, title: s.1, rounds: s.2, updated: "今天"))
        }
        return out
    }

    /// skill 分发目标（对齐 distribute.py 的 AGENT_DIRS）
    func defaultTargets() -> [SkillTarget] {
        [
            SkillTarget(id: "claude", dir: ".claude/skills", label: "Claude Code", recommended: false, checked: true),
            SkillTarget(id: "codex", dir: ".codex/skills", label: "Codex CLI", recommended: false, checked: true),
            SkillTarget(id: "agents", dir: ".agents/skills", label: "跨 agent 通用", recommended: true, checked: true),
            SkillTarget(id: "cline", dir: ".cline/skills", label: "Cline", recommended: false, checked: false),
        ]
    }
}
