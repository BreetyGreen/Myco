import Foundation

enum AgentID: String, CaseIterable, Identifiable, Codable {
    case claude, workbuddy, codex, cursor, antigravity
    var id: String { rawValue }

    var display: String {
        switch self {
        case .claude: return "Claude Code"
        case .workbuddy: return "WorkBuddy"
        case .codex: return "Codex CLI"
        case .cursor: return "Cursor"
        case .antigravity: return "Antigravity"
        }
    }
    /// 托盘/头像里的字母标
    var initial: String {
        switch self {
        case .claude: return "C"
        case .workbuddy: return "W"
        case .codex: return "X"
        case .cursor: return "U"
        case .antigravity: return "A"
        }
    }
    /// distribute.py 的 --agents 选择器（仅 CLI 类 agent 有对应 skill 目录）
    var skillSelector: String? {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        default: return nil
        }
    }
}

struct Agent: Identifiable {
    let id: AgentID
    var installed: Bool
    var sessionCount: Int
    var detail: String       // 版本/路径提示
    var display: String { id.display }
}

struct Session: Identifiable {
    let id: String           // 会话短 id
    let agent: AgentID
    let title: String
    let rounds: Int
    let updated: String
}

struct ShareableSkill: Identifiable {
    let id: String           // 目录名
    let name: String         // frontmatter name
    let desc: String
    let path: String
}

/// skill 分发的目标目录（对齐 distribute.py 的 AGENT_DIRS）
struct SkillTarget: Identifiable {
    let id: String           // selector: claude/codex/agents/cline
    let dir: String          // .claude/skills 等
    let label: String
    var recommended: Bool
    var checked: Bool
}
