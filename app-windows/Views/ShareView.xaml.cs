using System.Windows;
using System.Windows.Controls;

namespace Myco.Views;

public partial class ShareView : UserControl
{
    private int _skillIdx;
    private List<TargetVM> _targets = new();
    private bool _running;

    public ShareView()
    {
        InitializeComponent();
        AppStore.I.StateChanged += () => Dispatcher.Invoke(Rebuild);
        Rebuild();
    }

    private void Rebuild()
    {
        var skills = AppStore.I.Skills;
        if (skills.Count > 0)
        {
            var sk = skills[_skillIdx % skills.Count];
            SkillName.Text = sk.Name;
            SkillDesc.Text = sk.Desc;
            CycleBtn.Visibility = skills.Count > 1 ? Visibility.Visible : Visibility.Collapsed;
        }
        else
        {
            SkillName.Text = "（未找到可分发的 skill）";
            SkillDesc.Text = "资源根的 skills/ 目录里没有含 SKILL.md 的子目录。";
        }
        if (_targets.Count == 0)
        {
            _targets = AppStore.I.DefaultTargets();
            TargetsList.ItemsSource = _targets;
        }
    }

    private void OnCycleSkill(object sender, RoutedEventArgs e)
    {
        _skillIdx++;
        Rebuild();
    }

    private void OnToggleTarget(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TargetVM t }) t.Checked = !t.Checked;
    }

    private async void OnDistribute(object sender, RoutedEventArgs e)
    {
        if (_running || AppStore.I.Skills.Count == 0) return;
        var sk = AppStore.I.Skills[_skillIdx % AppStore.I.Skills.Count];
        var selected = _targets.Where(t => t.Checked).Select(t => t.Id).ToList();
        var dry = DryRun.IsChecked == true;
        if (selected.Count == 0)
        {
            ShowResult(dry, "请至少勾选一个目标 agent。");
            return;
        }

        _running = true;
        GoBtn.Content = "分发中…";
        GoBtn.IsEnabled = false;
        var r = await PythonBridge.Shared.DistributeAsync(
            sk.Path, PythonBridge.Shared.WorkDir, selected, dry);
        _running = false;
        GoBtn.IsEnabled = true;
        GoBtn.Content = dry ? "预演分发" : "分发 skill";

        var body = r.Stdout.Length > 0 ? r.Stdout : r.Stderr;
        ShowResult(dry, body.Length > 600 ? body[^600..] : body);
    }

    private void ShowResult(bool dry, string text)
    {
        ResultCard.Visibility = Visibility.Visible;
        ResultTitle.Text = dry ? "预演结果" : "已写入";
        ResultText.Text = text.Trim();
        GitHint.Visibility = dry ? Visibility.Collapsed : Visibility.Visible;
    }
}
