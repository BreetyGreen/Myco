import Foundation

/// 只读扫描本机 5 个 agent 的安装状态与会话数。
/// 路径与 scripts/chatsync/readers 完全一致，绝不写入任何 agent 存储。
struct AgentDetector {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    static func detectAll() -> [Agent] {
        [
            detectClaude(),
            detectWorkBuddy(),
            detectCodex(),
            detectCursor(),
            detectAntigravity(),
        ]
    }

    // ~/.claude/projects/**/*.jsonl
    private static func detectClaude() -> Agent {
        let dir = home.appendingPathComponent(".claude/projects")
        let n = countJSONL(dir)
        return Agent(id: .claude, installed: exists(home.appendingPathComponent(".claude")),
                     sessionCount: n, detail: "~/.claude/projects")
    }

    // ~/.workbuddy/projects/**/*.jsonl
    private static func detectWorkBuddy() -> Agent {
        let dir = home.appendingPathComponent(".workbuddy/projects")
        let n = countJSONL(dir)
        return Agent(id: .workbuddy, installed: exists(home.appendingPathComponent(".workbuddy")),
                     sessionCount: n, detail: "~/.workbuddy/projects")
    }

    // ~/.codex/sessions/**/*.jsonl (+ archived_sessions)
    private static func detectCodex() -> Agent {
        let base = home.appendingPathComponent(".codex")
        let n = countJSONL(base.appendingPathComponent("sessions"))
              + countJSONL(base.appendingPathComponent("archived_sessions"))
        return Agent(id: .codex, installed: exists(base),
                     sessionCount: n, detail: "~/.codex/sessions")
    }

    // ~/Library/Application Support/Cursor/User/globalStorage/state.vscdb
    private static func detectCursor() -> Agent {
        let base = home.appendingPathComponent("Library/Application Support/Cursor")
        let db = base.appendingPathComponent("User/globalStorage/state.vscdb")
        return Agent(id: .cursor, installed: exists(base),
                     sessionCount: exists(db) ? sqliteChatCount(db) : 0,
                     detail: "Cursor state.vscdb")
    }

    // ~/Library/Application Support/Antigravity/.../state.vscdb
    private static func detectAntigravity() -> Agent {
        let base = home.appendingPathComponent("Library/Application Support/Antigravity")
        let db = base.appendingPathComponent("User/globalStorage/state.vscdb")
        return Agent(id: .antigravity, installed: exists(base),
                     sessionCount: exists(db) ? sqliteChatCount(db) : 0,
                     detail: "Antigravity state.vscdb")
    }

    // ---- helpers ----
    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// 递归统计目录下 *.jsonl 文件数（近似会话数，够做概览展示）。
    private static func countJSONL(_ dir: URL) -> Int {
        guard exists(dir) else { return 0 }
        var count = 0
        if let en = FileManager.default.enumerator(at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]) {
            for case let f as URL in en where f.pathExtension == "jsonl" {
                count += 1
            }
        }
        return count
    }

    /// 粗略地用 sqlite3 CLI 读取 Cursor/Antigravity 的会话条数（只读 immutable）。
    /// 失败时返回 0，绝不抛错、绝不写库。
    private static func sqliteChatCount(_ db: URL) -> Int {
        let uri = "file:\(db.path)?immutable=1&mode=ro"
        let sql = "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%chat%' OR key LIKE '%composer%';"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [uri, sql]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
            return Int(s) ?? 0
        } catch { return 0 }
    }
}
