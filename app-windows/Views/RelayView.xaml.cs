using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Myco.Views;

public partial class RelayView : UserControl
{
    private static readonly (string Key, string Label)[] Modes =
        { ("auto", "自动"), ("full", "完整"), ("summary", "摘要"), ("recent", "近期") };

    private SessionVM? _picked;
    private string _mode = "auto";
    private bool _running;

    public RelayView()
    {
        InitializeComponent();
        BuildModeRow();
        AppStore.I.StateChanged += () => Dispatcher.Invoke(Rebuild);
        Rebuild();
    }

    private void Rebuild()
    {
        var s = AppStore.I;
        SessionsList.ItemsSource = null;
        SessionsList.ItemsSource = s.Sessions;
        if (s.Sessions.Count == 0)
        {
            EmptyHint.Visibility = Visibility.Visible;
            EmptyHint.Text = s.SessionsLoading ? "正在读取真实会话…" : "未检测到会话";
        }
        else
        {
            EmptyHint.Visibility = Visibility.Collapsed;
        }
    }

    private void BuildModeRow()
    {
        ModeRow.Children.Clear();
        foreach (var (key, label) in Modes)
        {
            var on = _mode == key;
            var pill = new Border
            {
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(11, 6, 11, 6),
                BorderThickness = new Thickness(0.6),
            };
            pill.SetResourceReference(Border.BackgroundProperty, on ? "BrandTint" : "Card2");
            pill.SetResourceReference(Border.BorderBrushProperty, on ? "BrandGlow" : "LineSoft");
            var tb = new TextBlock { Text = label, FontSize = 11.5, FontWeight = FontWeights.SemiBold };
            tb.SetResourceReference(TextBlock.ForegroundProperty, on ? "Brand" : "Text2");
            pill.Child = tb;
            var btn = new Button
            {
                Style = (Style)Application.Current.Resources["FlatBtn"],
                Content = pill, Tag = key, Margin = new Thickness(0, 0, 7, 0),
            };
            btn.Click += (s2, _) =>
            {
                _mode = (string)((Button)s2).Tag;
                BuildModeRow();
            };
            ModeRow.Children.Add(btn);
        }
    }

    private void OnPick(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: SessionVM s }) return;
        _picked = s;
        PickedBadge.Background = s.Badge;
        PickedInitial.Text = s.Initial;
        PickedTitle.Text = s.Title;
        PickedMeta.Text = $"{s.AgentDisplay} · {s.Id} · {s.Rounds} 轮";
        ResultCard.Visibility = Visibility.Collapsed;
        ListPane.Visibility = Visibility.Collapsed;
        PickedPane.Visibility = Visibility.Visible;
    }

    private void OnUnpick(object sender, RoutedEventArgs e)
    {
        _picked = null;
        ResultCard.Visibility = Visibility.Collapsed;
        PickedPane.Visibility = Visibility.Collapsed;
        ListPane.Visibility = Visibility.Visible;
    }

    private async void OnGenerate(object sender, RoutedEventArgs e)
    {
        if (_running || _picked is not { } s) return;
        _running = true;
        GenBtn.Content = "生成中…";
        GenBtn.IsEnabled = false;

        var file = $"handoff-{s.Agent}-{s.Id}.md";
        var outPath = Path.Combine(PythonBridge.Shared.WorkDir, file);
        var r = await PythonBridge.Shared.HandoffBuildAsync(s.Id, _mode, outPath);

        _running = false;
        GenBtn.IsEnabled = true;
        GenBtn.Content = "生成接力包";
        ResultCard.Visibility = Visibility.Visible;
        if (r.Ok)
        {
            ResultTitle.Text = "接力包已生成";
            ResultText.Text = $"已写入 {file}（并复制到剪贴板）。粘贴到目标产品的新会话即可继续。";
        }
        else
        {
            ResultTitle.Text = "生成失败";
            var body = r.Stderr.Length > 0 ? r.Stderr : r.Stdout;
            ResultText.Text = body.Length > 400 ? body[^400..] : body;
        }
    }
}
