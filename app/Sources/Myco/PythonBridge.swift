import Foundation

/// 执行结果
struct RunResult {
    let ok: Bool
    let stdout: String
    let stderr: String
    let code: Int32
}

/// Swift → Myco 内部 Python 引擎的调用桥。
/// distribute.py（skill 扇出）/ sync_chats.py（历史聚合）/ handoff_chat.py（会话接力）。
/// 全部只读或只产出文本文件，符合项目隐私承诺。
final class PythonBridge {
    static let shared = PythonBridge()

    /// 资源根（只读）：Python 引擎 engine/ 与随附 skills/ 所在处。
    /// 查找顺序：环境变量 MYCO_REPO（开发覆盖）→ Bundle 内 Resources（安装版）
    ///           → 从二进制位置向上搜索（源码树运行）→ 开发兜底。
    /// 安装到 /Applications 后，bundle 内部是只读且已签名的，绝不往里写任何文件。
    lazy var resourceRoot: URL = Self.locateResourceRoot()

    /// 工作目录（可写）：接力包、聚合归档、skill 分发目标都落这里。
    /// 默认 ~/Documents/Myco，首次访问时自动创建。签名 bundle 内部不可写，故必须外置。
    lazy var workDir: URL = Self.ensureWorkDir()

    /// 兼容旧调用点：语义上等同资源根（只读）。写操作请显式用 workDir。
    var repoRoot: URL { resourceRoot }

    private static func hasEngine(_ dir: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("engine/distribute.py").path)
    }

    private static func locateResourceRoot() -> URL {
        let fm = FileManager.default
        // 1) 开发覆盖
        if let env = ProcessInfo.processInfo.environment["MYCO_REPO"],
           hasEngine(URL(fileURLWithPath: env)) {
            return URL(fileURLWithPath: env)
        }
        // 2) 安装版：引擎随 bundle 打包在 Contents/Resources/
        let bundleRes = Bundle.main.resourceURL ?? Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources")
        if hasEngine(bundleRes) { return bundleRes }
        // 3) 源码树运行：从二进制位置向上找 engine/distribute.py
        var dir = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<8 {
            if hasEngine(dir) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        // 4) 兜底：当前工作目录（源码树里直接 `swift run` 时通常就是仓库根）
        return URL(fileURLWithPath: fm.currentDirectoryPath)
    }

    private static func ensureWorkDir() -> URL {
        let fm = FileManager.default
        // 允许用 MYCO_WORKDIR 覆盖；否则 ~/Documents/Myco
        let base: URL
        if let env = ProcessInfo.processInfo.environment["MYCO_WORKDIR"] {
            base = URL(fileURLWithPath: env)
        } else {
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
            base = docs.appendingPathComponent("Myco")
        }
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private var python: String {
        // 生产优先系统自带 python3（每台 mac 都有，且引擎纯 stdlib）；
        // 开发环境可用 MYCO_PYTHON 覆盖指向托管解释器。
        if let env = ProcessInfo.processInfo.environment["MYCO_PYTHON"],
           FileManager.default.isExecutableFile(atPath: env) {
            return env
        }
        let candidates = [
            "/usr/bin/python3",           // macOS 自带（CLT），最稳
            "/opt/homebrew/bin/python3",  // Apple Silicon Homebrew
            "/usr/local/bin/python3",     // Intel Homebrew
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/usr/bin/python3"
    }

    /// 通用执行
    func run(script: String, args: [String], cwd: URL? = nil) -> RunResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: python)
        // 引擎脚本从只读资源根加载；工作目录默认落在可写的 workDir。
        p.arguments = [resourceRoot.appendingPathComponent(script).path] + args
        p.currentDirectoryURL = cwd ?? workDir
        // 让 chatsync 包可被 import（脚本用了 sys.path 相对定位，这里再兜底一层）
        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = resourceRoot.appendingPathComponent("engine").path
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do {
            try p.run(); p.waitUntilExit()
        } catch {
            return RunResult(ok: false, stdout: "", stderr: "launch failed: \(error)", code: -1)
        }
        let so = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let se = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return RunResult(ok: p.terminationStatus == 0, stdout: so, stderr: se, code: p.terminationStatus)
    }

    func runAsync(script: String, args: [String], cwd: URL? = nil,
                  done: @escaping (RunResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let r = self.run(script: script, args: args, cwd: cwd)
            DispatchQueue.main.async { done(r) }
        }
    }

    // ---- 三大能力封装 ----

    /// skill 扇出：distribute.py --src <src> --dest <dest> --agents a,b [--dry-run]
    func distribute(src: String, dest: String, agents: [String], dryRun: Bool,
                    done: @escaping (RunResult) -> Void) {
        var args = ["--src", src, "--dest", dest, "--agents", agents.joined(separator: ",")]
        if dryRun { args.append("--dry-run") }
        runAsync(script: "engine/distribute.py", args: args, done: done)
    }

    /// 历史聚合：sync_chats.py --agents ... --out ... [--since] [--html] [--dry-run]
    func syncChats(agents: [String], out: String, since: String? = nil,
                   html: Bool = true, dryRun: Bool = false,
                   done: @escaping (RunResult) -> Void) {
        var args = ["--agents", agents.joined(separator: ","), "--out", out]
        if let s = since, !s.isEmpty { args += ["--since", s] }
        if html { args.append("--html") }
        if dryRun { args.append("--dry-run") }
        runAsync(script: "engine/sync_chats.py", args: args, done: done)
    }

    /// 列出可接力的候选会话：handoff_chat.py --agents ... --list
    func handoffList(agents: [String], search: String = "",
                     done: @escaping (RunResult) -> Void) {
        var args = ["--agents", agents.joined(separator: ","), "--list"]
        if !search.isEmpty { args += ["--search", search] }
        runAsync(script: "engine/handoff_chat.py", args: args, done: done)
    }

    /// 列出真实会话（机读 JSON）：handoff_chat.py --list --json
    /// 解析为 [Session]（title 支持中文，走 JSON 不受列宽/CJK 宽度影响）。
    func handoffListSessions(agents: [String], search: String = "",
                             done: @escaping ([Session]) -> Void) {
        var args = ["--agents", agents.joined(separator: ","), "--list", "--json"]
        if !search.isEmpty { args += ["--search", search] }
        runAsync(script: "engine/handoff_chat.py", args: args) { r in
            done(Self.parseSessions(r.stdout))
        }
    }

    /// 解析 handoff_chat.py --json 的输出为 [Session]。失败返回空数组。
    static func parseSessions(_ stdout: String) -> [Session] {
        guard let data = stdout.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["sessions"] as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { s in
            guard let short = s["shortid"] as? String,
                  let agentStr = s["agent"] as? String,
                  let agent = AgentID(rawValue: agentStr) else { return nil }
            let title = (s["title"] as? String) ?? "(无标题)"
            let msgs = (s["msgs"] as? Int) ?? 0
            let date = (s["date"] as? String) ?? ""
            return Session(id: short, agent: agent, title: title,
                           rounds: msgs, updated: date.isEmpty ? "—" : date)
        }
    }

    /// 生成会话接力包：handoff_chat.py --session <id> --mode <m> --out <file> --print
    func handoffBuild(session: String, mode: String, out: String,
                      done: @escaping (RunResult) -> Void) {
        let args = ["--session", session, "--mode", mode, "--out", out, "--print"]
        runAsync(script: "engine/handoff_chat.py", args: args, done: done)
    }
}
