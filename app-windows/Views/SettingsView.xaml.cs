using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;

namespace Myco.Views;

public partial class SettingsView : UserControl
{
    public SettingsView()
    {
        InitializeComponent();
        ResourcePath.Text = PythonBridge.Shared.ResourceRoot;
        WorkPath.Text = PythonBridge.Shared.WorkDir;
        PythonPath.Text = PythonBridge.Shared.PythonLabel;
        Theme.Changed += () => Dispatcher.Invoke(UpdateThemeLabel);
        UpdateThemeLabel();
    }

    private void UpdateThemeLabel()
    {
        ThemeLabel.Text = Theme.Dark ? "深色" : "浅色";
        ThemeBtnLabel.Text = Theme.Dark ? "深色" : "浅色";
    }

    private void OnToggleTheme(object sender, RoutedEventArgs e) => Theme.Toggle();

    private void OnRefresh(object sender, RoutedEventArgs e) => _ = AppStore.I.RefreshAsync();

    private void OnOpenWorkDir(object sender, RoutedEventArgs e)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = PythonBridge.Shared.WorkDir,
            UseShellExecute = true,   // 交给资源管理器打开目录
        });
    }
}
