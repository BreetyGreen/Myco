using System.IO;
using System.Text.Json;

namespace Myco;

/// 全局状态中枢（对齐 macOS 版 AppStore.swift）：tab、agent、skill、会话、加载态。
/// 视图监听 StateChanged / TabChanged 重建。
public sealed class AppStore
{
    public static readonly AppStore I = new();

    public List<AgentVM> Agents { get; private set; } = new();
    public List<SkillVM> Skills { get; private set; } = new();
    public List<SessionVM> Sessions { get; private set; } = new();
    public bool SessionsLoading { get; private set; }
    public string Tab { get; private set; } = "home";

    /// agents/skills/sessions 任一批量变化后触发，视图整体重建。
    public event Action? StateChanged;
    public event Action<string>? TabChanged;

    public IEnumerable<AgentVM> Installed => Agents.Where(a => a.Installed);
    public int InstalledCount => Installed.Count();
    public int TotalSessions => Agents.Sum(a => a.Sessions);

    public void SetTab(string tab)
    {
        Tab = tab;
        TabChanged?.Invoke(tab);
    }

    /// 两段式刷新：先秒出 agent 概览（快），真实会话列表（扫全部历史，慢）后到。
    public async Task RefreshAsync()
    {
        var status = await PythonBridge.Shared.AgentStatusAsync();
        Agents = ParseAgents(status.Stdout);
        Skills = LoadShareableSkills();
        Sessions = new List<SessionVM>();
        StateChanged?.Invoke();

        var ids = Installed.Select(a => a.Id).ToList();
        if (ids.Count == 0) return;
        SessionsLoading = true;
        StateChanged?.Invoke();
        Sessions = await PythonBridge.Shared.HandoffListAsync(ids);
        SessionsLoading = false;
        StateChanged?.Invoke();
    }

    private static List<AgentVM> ParseAgents(string stdout)
    {
        var list = new List<AgentVM>();
        try
        {
            using var doc = JsonDocument.Parse(stdout);
            if (!doc.RootElement.TryGetProperty("agents", out var arr)) return list;
            foreach (var a in arr.EnumerateArray())
            {
                string S(string key, string fb = "") =>
                    a.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString()! : fb;
                bool Bl(string key) =>
                    a.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.True;
                var id = S("id");
                if (id.Length == 0) continue;
                list.Add(new AgentVM(
                    id, S("display", id), S("initial", id[..1].ToUpperInvariant()),
                    Bl("installed"),
                    a.TryGetProperty("sessions", out var n) && n.TryGetInt32(out var ni) ? ni : 0,
                    Bl("approximate"), Bl("pathChanged"), S("detail")));
            }
        }
        catch (JsonException) { }
        return list;
    }

    /// 从随附 skills/ 目录读取可分发的 SKILL.md（真实存在的）。
    private static List<SkillVM> LoadShareableSkills()
    {
        var root = Path.Combine(PythonBridge.Shared.ResourceRoot, "skills");
        var outList = new List<SkillVM>();
        if (Directory.Exists(root))
        {
            foreach (var dir in Directory.EnumerateDirectories(root))
            {
                var md = Path.Combine(dir, "SKILL.md");
                if (!File.Exists(md)) continue;
                var text = File.ReadAllText(md);
                var name = Frontmatter(text, "name") ?? Path.GetFileName(dir);
                var desc = Frontmatter(text, "description") ?? "（无描述）";
                outList.Add(new SkillVM(Path.GetFileName(dir), name,
                    desc.Length > 90 ? desc[..90] : desc, dir));
            }
        }
        return outList;
    }

    private static string? Frontmatter(string text, string key)
    {
        var lines = text.Split('\n').Take(20).ToArray();
        for (var i = 0; i < lines.Length; i++)
        {
            var l = lines[i].Trim();
            if (!l.StartsWith(key + ":")) continue;
            var val = l[(key.Length + 1)..].Trim().Trim('"', '\'');
            // YAML 块标量（>- / > / |- / |）：取后续缩进行拼成一段
            if (val is ">" or ">-" or "|" or "|-" or "")
            {
                var parts = new List<string>();
                for (var j = i + 1; j < lines.Length; j++)
                {
                    if (lines[j].Length == 0 || !char.IsWhiteSpace(lines[j][0])) break;
                    parts.Add(lines[j].Trim());
                }
                val = string.Join(" ", parts);
            }
            return val.Length > 0 ? val : null;
        }
        return null;
    }

    /// skill 分发目标：agents.json 驱动（agents[] + extraSkillTargets），
    /// defaultDistribute 决定默认勾选。
    public List<TargetVM> DefaultTargets()
    {
        var path = Path.Combine(PythonBridge.Shared.ResourceRoot, "engine", "agents.json");
        var outList = new List<TargetVM>();
        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(path));
            var root = doc.RootElement;
            var defaults = new HashSet<string>();
            if (root.TryGetProperty("defaultDistribute", out var dd))
                foreach (var d in dd.EnumerateArray())
                    if (d.GetString() is { } s) defaults.Add(s);

            if (root.TryGetProperty("agents", out var agents))
                foreach (var a in agents.EnumerateArray())
                {
                    var id = a.TryGetProperty("id", out var v) ? v.GetString() : null;
                    var dir = a.TryGetProperty("skillDir", out var v2) ? v2.GetString() : null;
                    if (id is null || dir is null) continue;
                    outList.Add(new TargetVM
                    {
                        Id = id, Dir = dir,
                        Label = a.TryGetProperty("display", out var v3) ? (v3.GetString() ?? id) : id,
                        Recommended = false, Checked = defaults.Contains(id),
                    });
                }
            if (root.TryGetProperty("extraSkillTargets", out var extra))
                foreach (var e in extra.EnumerateArray())
                {
                    var id = e.TryGetProperty("id", out var v) ? v.GetString() : null;
                    var dir = e.TryGetProperty("dir", out var v2) ? v2.GetString() : null;
                    if (id is null || dir is null) continue;
                    outList.Add(new TargetVM
                    {
                        Id = id, Dir = dir,
                        Label = e.TryGetProperty("label", out var v3) ? (v3.GetString() ?? id) : id,
                        Recommended = id == "agents", Checked = defaults.Contains(id),
                    });
                }
        }
        catch (Exception) { /* 注册表缺失/损坏时返回已收集到的部分 */ }
        return outList;
    }
}
