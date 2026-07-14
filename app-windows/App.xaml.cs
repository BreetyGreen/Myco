using System.Windows;
using WF = System.Windows.Forms;

namespace Myco;

/// 纯托盘应用：无主窗口，NotifyIcon + 无边框弹出面板。
public partial class App : Application
{
    private WF.NotifyIcon? _tray;
    private PopupWindow? _popup;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        Theme.Apply(dark: Environment.GetEnvironmentVariable("MYCO_THEME") != "light");

        _popup = new PopupWindow();

        _tray = new WF.NotifyIcon
        {
            Icon = TrayIconFactory.Make(),
            Text = "Myco — the mycelial layer for your agents",
            Visible = true,
        };
        _tray.MouseUp += (_, me) =>
        {
            if (me.Button == WF.MouseButtons.Left) _popup!.TogglePopup();
        };
        var menu = new WF.ContextMenuStrip();
        menu.Items.Add("打开 Myco", null, (_, _) => _popup!.ShowPopup());
        menu.Items.Add("重新检测", null, (_, _) => _ = AppStore.I.RefreshAsync());
        menu.Items.Add(new WF.ToolStripSeparator());
        menu.Items.Add("退出", null, (_, _) => Shutdown());
        _tray.ContextMenuStrip = menu;

        // 首次启动异步检测本机 agent
        _ = AppStore.I.RefreshAsync();

        // 预览模式：直接把面板当普通窗口摆出来（截图/演示用）
        if (Environment.GetEnvironmentVariable("MYCO_PREVIEW") != null)
        {
            if (Environment.GetEnvironmentVariable("MYCO_TAB") is { } t) AppStore.I.SetTab(t);
            _popup.ShowCentered();

            // 自渲染截图：等 agent 异步检测 + 布局完成后输出 PNG（MYCO_SHOT_QUIT 则退出）。
            if (Environment.GetEnvironmentVariable("MYCO_SHOT") is { } shot)
            {
                var delay = double.TryParse(
                    Environment.GetEnvironmentVariable("MYCO_SHOT_DELAY"), out var d) ? d : 2.5;
                var timer = new System.Windows.Threading.DispatcherTimer
                    { Interval = TimeSpan.FromSeconds(delay) };
                timer.Tick += (_, _) =>
                {
                    timer.Stop();
                    _popup.Snapshot(shot);
                    if (Environment.GetEnvironmentVariable("MYCO_SHOT_QUIT") != null) Shutdown();
                };
                timer.Start();
            }
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_tray != null) { _tray.Visible = false; _tray.Dispose(); }
        base.OnExit(e);
    }
}
