using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;

namespace Myco;

public record RunResult(bool Ok, string Stdout, string Stderr, int Code);

/// C# → Myco 内部 Python 引擎的调用桥（对齐 macOS 版 PythonBridge.swift）。
/// distribute.py（skill 扇出）/ sync_chats.py（历史聚合）/ handoff_chat.py（会话接力）
/// / agent_status.py（agent 检测）。全部只读或只产出文本文件。
public sealed class PythonBridge
{
    public static readonly PythonBridge Shared = new();

    /// 资源根（只读）：engine/ 与随附 skills/ 所在处。
    /// 查找顺序：MYCO_REPO（开发覆盖）→ exe 同目录（分发包）→ 从 exe 向上搜索（源码树）→ 当前目录。
    public string ResourceRoot { get; }

    /// 工作目录（可写）：接力包、聚合归档、skill 分发目标都落这里。
    /// MYCO_WORKDIR 覆盖；默认 ~/Documents/Myco，首次访问自动创建。
    public string WorkDir { get; }

    private readonly string _pythonExe;
    private readonly string[] _pythonPrefixArgs;

    private PythonBridge()
    {
        ResourceRoot = LocateResourceRoot();
        WorkDir = EnsureWorkDir();
        (_pythonExe, _pythonPrefixArgs) = LocatePython();
    }

    public bool PythonFound => _pythonExe.Length > 0;
    public string PythonLabel => PythonFound ? _pythonExe : "(未找到 Python)";

    private static bool HasEngine(string dir) =>
        File.Exists(Path.Combine(dir, "engine", "distribute.py"));

    private static string LocateResourceRoot()
    {
        var env = Environment.GetEnvironmentVariable("MYCO_REPO");
        if (!string.IsNullOrEmpty(env) && HasEngine(env)) return env;

        var exeDir = AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
        if (HasEngine(exeDir)) return exeDir;

        var dir = exeDir;
        for (var i = 0; i < 8; i++)
        {
            var parent = Path.GetDirectoryName(dir);
            if (string.IsNullOrEmpty(parent)) break;
            dir = parent;
            if (HasEngine(dir)) return dir;
        }
        return Directory.GetCurrentDirectory();
    }

    private static string EnsureWorkDir()
    {
        var env = Environment.GetEnvironmentVariable("MYCO_WORKDIR");
        var baseDir = !string.IsNullOrEmpty(env)
            ? env
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Myco");
        Directory.CreateDirectory(baseDir);
        return baseDir;
    }

    /// Python 查找顺序：MYCO_PYTHON → 随包 python/python.exe（embeddable，exe 同目录或资源根）
    /// → py 启动器 → PATH 上的 python。
    private (string exe, string[] prefix) LocatePython()
    {
        var env = Environment.GetEnvironmentVariable("MYCO_PYTHON");
        if (!string.IsNullOrEmpty(env) && File.Exists(env)) return (env, Array.Empty<string>());

        foreach (var root in new[] { AppContext.BaseDirectory, ResourceRoot })
        {
            var bundled = Path.Combine(root, "python", "python.exe");
            if (File.Exists(bundled)) return (bundled, Array.Empty<string>());
        }

        if (OnPath("py.exe") is { } py) return (py, new[] { "-3" });
        if (OnPath("python.exe") is { } python) return (python, Array.Empty<string>());
        return ("", Array.Empty<string>());
    }

    private static string? OnPath(string name)
    {
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';'))
        {
            if (string.IsNullOrWhiteSpace(dir)) continue;
            try
            {
                var p = Path.Combine(dir.Trim(), name);
                if (File.Exists(p)) return p;
            }
            catch (ArgumentException) { /* PATH 里混入非法字符的目录，跳过 */ }
        }
        return null;
    }

    /// 通用执行：起 python 跑 <ResourceRoot>/<script>，工作目录默认 WorkDir。
    public RunResult Run(string script, IEnumerable<string> args, string? cwd = null)
    {
        if (!PythonFound)
            return new RunResult(false, "", "未找到 Python：请安装 Python 3，或使用带 python/ 目录的完整分发包。", -1);

        var psi = new ProcessStartInfo
        {
            FileName = _pythonExe,
            UseShellExecute = false,
            CreateNoWindow = true,           // 防止每次引擎调用闪一个黑色控制台
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            WorkingDirectory = cwd ?? WorkDir,
        };
        foreach (var a in _pythonPrefixArgs) psi.ArgumentList.Add(a);
        psi.ArgumentList.Add(Path.Combine(ResourceRoot, script));
        foreach (var a in args) psi.ArgumentList.Add(a);
        // 防 GBK 控制台编码毁掉 CJK 输出；让 chatsync 包可被 import。
        psi.Environment["PYTHONUTF8"] = "1";
        psi.Environment["PYTHONIOENCODING"] = "utf-8";
        psi.Environment["PYTHONPATH"] = Path.Combine(ResourceRoot, "engine");

        try
        {
            using var p = Process.Start(psi)!;
            var so = p.StandardOutput.ReadToEnd();
            var se = p.StandardError.ReadToEnd();
            p.WaitForExit();
            return new RunResult(p.ExitCode == 0, so, se, p.ExitCode);
        }
        catch (Exception e)
        {
            return new RunResult(false, "", $"launch failed: {e.Message}", -1);
        }
    }

    public Task<RunResult> RunAsync(string script, IEnumerable<string> args, string? cwd = null) =>
        Task.Run(() => Run(script, args, cwd));

    // ---- 能力封装 ----

    /// agent 检测：agent_status.py --json（检测逻辑单一实现在引擎里）
    public Task<RunResult> AgentStatusAsync() =>
        RunAsync("engine/agent_status.py", new[] { "--json" });

    /// skill 扇出：distribute.py --src <src> --dest <dest> --agents a,b [--dry-run]
    public Task<RunResult> DistributeAsync(string src, string dest, IEnumerable<string> agents, bool dryRun)
    {
        var args = new List<string> { "--src", src, "--dest", dest, "--agents", string.Join(",", agents) };
        if (dryRun) args.Add("--dry-run");
        return RunAsync("engine/distribute.py", args);
    }

    /// 历史聚合：sync_chats.py --agents ... --out ... [--html] [--dry-run]
    public Task<RunResult> SyncChatsAsync(IEnumerable<string> agents, string outDir, bool html, bool dryRun)
    {
        var args = new List<string> { "--agents", string.Join(",", agents), "--out", outDir };
        if (html) args.Add("--html");
        if (dryRun) args.Add("--dry-run");
        return RunAsync("engine/sync_chats.py", args);
    }

    /// 列出真实会话（机读 JSON）：handoff_chat.py --list --json
    public async Task<List<SessionVM>> HandoffListAsync(IEnumerable<string> agents)
    {
        var r = await RunAsync("engine/handoff_chat.py",
            new[] { "--agents", string.Join(",", agents), "--list", "--json" });
        return ParseSessions(r.Stdout);
    }

    /// 生成会话接力包：handoff_chat.py --session <id> --mode <m> --out <file> --print
    public Task<RunResult> HandoffBuildAsync(string session, string mode, string outFile) =>
        RunAsync("engine/handoff_chat.py",
            new[] { "--session", session, "--mode", mode, "--out", outFile, "--print" });

    /// 解析 handoff_chat.py --json 输出。失败返回空列表。
    public static List<SessionVM> ParseSessions(string stdout)
    {
        var list = new List<SessionVM>();
        try
        {
            using var doc = JsonDocument.Parse(stdout);
            if (!doc.RootElement.TryGetProperty("sessions", out var arr)) return list;
            foreach (var s in arr.EnumerateArray())
            {
                var id = s.TryGetProperty("shortid", out var v1) ? v1.GetString() : null;
                var agent = s.TryGetProperty("agent", out var v2) ? v2.GetString() : null;
                if (id is null || agent is null) continue;
                list.Add(new SessionVM(
                    id, agent,
                    s.TryGetProperty("title", out var t) ? (t.GetString() ?? "(无标题)") : "(无标题)",
                    s.TryGetProperty("msgs", out var m) && m.TryGetInt32(out var mi) ? mi : 0,
                    s.TryGetProperty("date", out var d) ? (d.GetString() is { Length: > 0 } ds ? ds : "—") : "—"));
            }
        }
        catch (JsonException) { }
        return list;
    }
}
