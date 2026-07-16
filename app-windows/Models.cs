using System.ComponentModel;
using System.Windows.Media;

namespace Myco;

/// 本机检测到的 agent（数据来自 engine/agent_status.py --json）。
public sealed record AgentVM(
    string Id, string Display, string Initial,
    bool Installed, int Sessions, bool Approximate, bool PathChanged,
    string Detail)
{
    public Brush Badge => Theme.AgentColor(Id);
    public string CountLabel => PathChanged
        ? "结构已变"
        : Installed ? (Approximate ? $"约 {Sessions} 段" : $"{Sessions} 段") : "未安装";
    public Brush CountBrush => (Brush)System.Windows.Application.Current.Resources[
        PathChanged ? "Warn" : Installed ? "Brand" : "Text3"];
    public Brush DotBrush => (Brush)System.Windows.Application.Current.Resources[
        Installed ? "Brand" : "Text3"];
}

/// 可接力的会话（数据来自 handoff_chat.py --list --json）。
public sealed record SessionVM(string Id, string Agent, string Title, int Rounds, string Updated,
                               string Project = "")
{
    public Brush Badge => Theme.AgentColor(Agent);
    public string Initial => Agent switch
    {
        "claude" => "C", "workbuddy" => "W", "codex" => "X",
        "cursor" => "U", "antigravity" => "A", _ => Agent[..1].ToUpperInvariant(),
    };
    public string AgentDisplay => Agent switch
    {
        "claude" => "Claude Code", "workbuddy" => "WorkBuddy", "codex" => "Codex CLI",
        "cursor" => "Cursor", "antigravity" => "Antigravity", _ => Agent,
    };
    /// 工作空间短名（完整路径的最后一段）；无工作空间的会话为空。
    public string ProjectLabel
    {
        get
        {
            var p = Project.TrimEnd('/', '\\');
            if (p.Length == 0) return "";
            var i = p.LastIndexOfAny(new[] { '/', '\\' });
            return i >= 0 ? p[(i + 1)..] : p;
        }
    }
    public string Meta => ProjectLabel.Length > 0
        ? $"{ProjectLabel} · {Id} · {Rounds} 轮 · {Updated}"
        : $"{Id} · {Rounds} 轮 · {Updated}";
}

/// 随附 skills/ 目录里可分发的 skill。
public sealed record SkillVM(string Id, string Name, string Desc, string Path);

/// skill 分发目标（agents.json 的 agents[] + extraSkillTargets）。
public sealed class TargetVM : INotifyPropertyChanged
{
    public required string Id { get; init; }
    public required string Dir { get; init; }
    public required string Label { get; init; }
    public bool Recommended { get; init; }

    private bool _checked;
    public bool Checked
    {
        get => _checked;
        set { _checked = value; PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Checked))); }
    }

    public string DirLabel => $"<repo>/{Dir}/";
    public event PropertyChangedEventHandler? PropertyChanged;
}
