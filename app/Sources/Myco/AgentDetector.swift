import Foundation

/// 只读扫描本机各 agent 的安装状态与会话数。
/// 单一事实来源 = engine/agents.json（与 Python 引擎的 distribute.py 共用同一份），
/// 检测路径、会话读取方式都由它驱动，绝不写入任何 agent 存储。
/// 加一个新 agent / 改一条路径 = 只改 agents.json，无需重编译两处。
struct AgentDetector {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    // MARK: 注册表模型（对应 agents.json 的 agents[]）

    struct SessionSpec {
        enum Kind { case jsonl, sqlite, none }
        let kind: Kind
        let dirs: [String]     // jsonl: 递归统计 *.jsonl 的目录
        let db: String?        // sqlite: state.vscdb 路径
        let query: String?     // sqlite: COUNT 查询
    }

    struct Spec {
        let id: String
        let display: String
        let initial: String
        let root: String
        let detail: String
        let session: SessionSpec
    }

    /// 读取并缓存注册表（懒加载，只解析一次）。
    static let specs: [Spec] = loadSpecs()

    static func detectAll() -> [Agent] {
        specs.map { detect($0) }
    }

    // MARK: 注册表加载

    private static func loadSpecs() -> [Spec] {
        let url = PythonBridge.shared.resourceRoot
            .appendingPathComponent("engine/agents.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["agents"] as? [[String: Any]] else {
            return fallbackSpecs()
        }
        let parsed: [Spec] = arr.compactMap { a in
            guard let id = a["id"] as? String,
                  let display = a["display"] as? String else { return nil }
            let initial = (a["initial"] as? String) ?? String(display.prefix(1)).uppercased()
            let root = (a["root"] as? String) ?? ""
            let detail = (a["detail"] as? String) ?? root
            let s = a["sessions"] as? [String: Any] ?? [:]
            let kindStr = (s["kind"] as? String) ?? "none"
            let session: SessionSpec
            switch kindStr {
            case "jsonl":
                session = SessionSpec(kind: .jsonl,
                                      dirs: (s["dirs"] as? [String]) ?? [],
                                      db: nil, query: nil)
            case "sqlite":
                session = SessionSpec(kind: .sqlite, dirs: [],
                                      db: s["db"] as? String,
                                      query: s["query"] as? String)
            default:
                session = SessionSpec(kind: .none, dirs: [], db: nil, query: nil)
            }
            return Spec(id: id, display: display, initial: initial,
                        root: root, detail: detail, session: session)
        }
        return parsed.isEmpty ? fallbackSpecs() : parsed
    }

    /// 注册表缺失时的内置兜底（与 agents.json 内容保持一致）。
    private static func fallbackSpecs() -> [Spec] {
        [
            Spec(id: "claude", display: "Claude Code", initial: "C",
                 root: "~/.claude", detail: "~/.claude/projects",
                 session: SessionSpec(kind: .jsonl, dirs: ["~/.claude/projects"], db: nil, query: nil)),
            Spec(id: "workbuddy", display: "WorkBuddy", initial: "W",
                 root: "~/.workbuddy", detail: "~/.workbuddy/projects",
                 session: SessionSpec(kind: .jsonl, dirs: ["~/.workbuddy/projects"], db: nil, query: nil)),
            Spec(id: "codex", display: "Codex CLI", initial: "X",
                 root: "~/.codex", detail: "~/.codex/sessions",
                 session: SessionSpec(kind: .jsonl, dirs: ["~/.codex/sessions", "~/.codex/archived_sessions"], db: nil, query: nil)),
            Spec(id: "cursor", display: "Cursor", initial: "U",
                 root: "~/Library/Application Support/Cursor", detail: "Cursor state.vscdb",
                 session: SessionSpec(kind: .sqlite, dirs: [],
                                      db: "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb",
                                      query: "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%chat%' OR key LIKE '%composer%';")),
            Spec(id: "antigravity", display: "Antigravity", initial: "A",
                 root: "~/Library/Application Support/Antigravity", detail: "Antigravity state.vscdb",
                 session: SessionSpec(kind: .sqlite, dirs: [],
                                      db: "~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb",
                                      query: "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%chat%' OR key LIKE '%composer%';")),
        ]
    }

    // MARK: 单个 agent 检测

    private static func detect(_ spec: Spec) -> Agent {
        let rootURL = expand(spec.root)
        let rootExists = exists(rootURL)

        var count = 0
        var pathChanged = false   // root 在，但会话来源结构变了 → 提示而非静默

        switch spec.session.kind {
        case .jsonl:
            let existing = spec.session.dirs.map { expand($0) }.filter { exists($0) }
            count = existing.reduce(0) { $0 + countJSONL($1) }
            if rootExists && existing.isEmpty && !spec.session.dirs.isEmpty {
                pathChanged = true
            }
        case .sqlite:
            if let db = spec.session.db.map({ expand($0) }), exists(db) {
                count = sqliteCount(db, query: spec.session.query)
            } else if rootExists, spec.session.db != nil {
                pathChanged = true
            }
        case .none:
            break
        }

        let detail = pathChanged ? "\(spec.detail)（结构已变，未识别到会话）" : spec.detail
        return Agent(id: AgentID(rawValue: spec.id) ?? .claude,
                     installed: rootExists,
                     sessionCount: count,
                     detail: detail,
                     approximate: spec.session.kind == .jsonl,   // 数文件数是近似值
                     pathChanged: pathChanged)
    }

    // MARK: helpers

    /// 展开 agents.json 里以 ~ 开头的路径。
    private static func expand(_ path: String) -> URL {
        if path.hasPrefix("~") {
            let rest = String(path.dropFirst(path.hasPrefix("~/") ? 2 : 1))
            return home.appendingPathComponent(rest)
        }
        return URL(fileURLWithPath: path)
    }

    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// 递归统计目录下 *.jsonl 文件数（近似会话数，够做概览展示）。
    /// 带轻量缓存：以目录 mtime 为键，目录未变则直接复用上次结果，
    /// 避免会话多（100+）的用户每次打开面板都全盘重扫造成卡顿。
    private static var countCache: [String: (mtime: Date, count: Int)] = [:]
    private static let cacheLock = NSLock()

    private static func countJSONL(_ dir: URL) -> Int {
        guard exists(dir) else { return 0 }
        // 用目录自身的修改时间做缓存键：新增/删除会话文件会改变父目录 mtime。
        let mtime = (try? FileManager.default.attributesOfItem(atPath: dir.path)[.modificationDate] as? Date) ?? nil
        if let mtime {
            cacheLock.lock()
            if let hit = countCache[dir.path], hit.mtime == mtime {
                cacheLock.unlock()
                return hit.count
            }
            cacheLock.unlock()
        }

        var count = 0
        if let en = FileManager.default.enumerator(at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]) {
            for case let f as URL in en where f.pathExtension == "jsonl" {
                count += 1
            }
        }

        if let mtime {
            cacheLock.lock()
            countCache[dir.path] = (mtime, count)
            cacheLock.unlock()
        }
        return count
    }

    /// 只读（immutable）方式用 sqlite3 CLI 统计会话条数；失败返回 0，绝不写库。
    private static func sqliteCount(_ db: URL, query: String?) -> Int {
        let sql = query ?? "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%chat%' OR key LIKE '%composer%';"
        let uri = "file:\(db.path)?immutable=1&mode=ro"
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
