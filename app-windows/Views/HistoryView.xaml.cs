using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace Myco.Views;

public partial class HistoryView : UserControl
{
    private bool _running;

    public HistoryView()
    {
        InitializeComponent();
        AppStore.I.StateChanged += () => Dispatcher.Invoke(Rebuild);
        Theme.Changed += () => Dispatcher.Invoke(Rebuild);
        Rebuild();
    }

    private void Rebuild()
    {
        InstalledList.ItemsSource = null;
        InstalledList.ItemsSource = AppStore.I.Installed.ToList();
    }

    private async void OnSync(object sender, RoutedEventArgs e)
    {
        if (_running) return;
        var agents = AppStore.I.Installed.Select(a => a.Id).ToList();
        if (agents.Count == 0) return;

        _running = true;
        SyncBtn.Content = "聚合中…";
        SyncBtn.IsEnabled = false;
        var outDir = Path.Combine(PythonBridge.Shared.WorkDir, "chat-archive");
        var r = await PythonBridge.Shared.SyncChatsAsync(agents, outDir, html: true, dryRun: false);
        _running = false;
        SyncBtn.IsEnabled = true;
        SyncBtn.Content = "聚合并生成时间线";

        ResultCard.Visibility = Visibility.Visible;
        var body = r.Stdout.Length > 0 ? r.Stdout : r.Stderr;
        ResultText.Text = (body.Length > 600 ? body[^600..] : body).Trim();
    }
}
