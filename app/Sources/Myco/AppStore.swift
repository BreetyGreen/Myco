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
    @Published var sessionsLoading = false   // 真实会话异步加载中

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

    /// 异步检测本机 agent + 加载可分发 skill；随后再异步拉取真实会话列表。
    /// 两段式：先秒出 agent 概览（快），会话列表（要扫全部历史，慢）后到。
    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let detected = AgentDetector.detectAll()
            let skills = Self.loadShareableSkills()
            DispatchQueue.main.async {
                self.agents = detected
                self.skills = skills
                self.sessions = []
                self.loadRealSessions()   // 接真实会话（异步）
            }
        }
    }

    /// 调 handoff_chat.py --list --json 拉取真实会话，替换早期的占位数据。
    func loadRealSessions() {
        let installedIDs = installed.map { $0.id.rawValue }
        guard !installedIDs.isEmpty else { sessions = []; return }
        sessionsLoading = true
        PythonBridge.shared.handoffListSessions(agents: installedIDs) { [weak self] real in
            guard let self else { return }
            self.sessions = real
            self.sessionsLoading = false
        }
    }

    /// 从随附的 skills/ 目录读取可分发的 SKILL.md（真实存在的）。
    static func loadShareableSkills() -> [ShareableSkill] {
        let root = PythonBridge.shared.resourceRoot.appendingPathComponent("skills")
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

    /// skill 分发目标：从注册表(agents.json)驱动，与检测端 5 个 agent 完全对齐，
    /// 再加上跨 agent 通用目录(.agents)。彻底消除"检测到的 ≠ 能分享的"。
    func defaultTargets() -> [SkillTarget] {
        let url = PythonBridge.shared.resourceRoot
            .appendingPathComponent("engine/agents.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return fallbackTargets()
        }
        let defaults = Set((obj["defaultDistribute"] as? [String]) ?? ["claude", "codex", "workbuddy", "agents"])
        var out: [SkillTarget] = []
        // 5 个 agent（来自 agents[]）
        if let arr = obj["agents"] as? [[String: Any]] {
            for a in arr {
                guard let id = a["id"] as? String,
                      let dir = a["skillDir"] as? String else { continue }
                let label = (a["display"] as? String) ?? id
                out.append(SkillTarget(id: id, dir: dir, label: label,
                                       recommended: false, checked: defaults.contains(id)))
            }
        }
        // 额外跨 agent 目标（.agents / .cline）
        if let extra = obj["extraSkillTargets"] as? [[String: Any]] {
            for e in extra {
                guard let id = e["id"] as? String,
                      let dir = e["dir"] as? String else { continue }
                let label = (e["label"] as? String) ?? id
                out.append(SkillTarget(id: id, dir: dir, label: label,
                                       recommended: id == "agents", checked: defaults.contains(id)))
            }
        }
        return out.isEmpty ? fallbackTargets() : out
    }

    private func fallbackTargets() -> [SkillTarget] {
        [
            SkillTarget(id: "claude", dir: ".claude/skills", label: "Claude Code", recommended: false, checked: true),
            SkillTarget(id: "codex", dir: ".codex/skills", label: "Codex CLI", recommended: false, checked: true),
            SkillTarget(id: "workbuddy", dir: ".workbuddy/skills", label: "WorkBuddy", recommended: false, checked: true),
            SkillTarget(id: "agents", dir: ".agents/skills", label: "跨 agent 通用", recommended: true, checked: true),
            SkillTarget(id: "cline", dir: ".cline/skills", label: "Cline", recommended: false, checked: false),
        ]
    }
}
