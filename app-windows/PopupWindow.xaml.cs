using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Myco.Views;

namespace Myco;

/// 弹出面板外壳：头部 + 内容区 + 底部 tab。贴任务栏托盘弹出，失焦即隐藏。
public partial class PopupWindow : Window
{
    private readonly Dictionary<string, UserControl> _views = new();
    private readonly Dictionary<string, (Button btn, string glyph, string label)> _tabs;
    private DateTime _lastHide = DateTime.MinValue;
    private bool _pinned;   // 预览模式：不自动隐藏

    public PopupWindow()
    {
        InitializeComponent();
        _tabs = new()
        {
            ["home"]     = (TabHome,     "", "总览"),
            ["share"]    = (TabShare,    "", "共享"),
            ["relay"]    = (TabRelay,    "", "接力"),
            ["history"]  = (TabHistory,  "", "历史"),
            ["settings"] = (TabSettings, "", "设置"),
        };
        foreach (var (key, t) in _tabs) t.btn.Content = BuildTabContent(key);

        AppStore.I.TabChanged += _ => Dispatcher.Invoke(UpdateTab);
        Theme.Changed += () => Dispatcher.Invoke(() =>
        {
            ThemeGlyph.Text = Theme.Dark ? "" : "";   // 太阳 / 月亮
            UpdateTab();
        });
        Deactivated += (_, _) =>
        {
            if (_pinned) return;
            Hide();
            _lastHide = DateTime.UtcNow;
        };
        UpdateTab();
    }

    // ---- 弹出/隐藏 ----

    public void TogglePopup()
    {
        // 面板开着时点托盘：Deactivated 已先把它藏了，这次点击视为“关闭”而不是再弹出。
        if (IsVisible) { Hide(); return; }
        if ((DateTime.UtcNow - _lastHide).TotalMilliseconds < 300) return;
        ShowPopup();
    }

    public void ShowPopup()
    {
        var wa = SystemParameters.WorkArea;   // DIP 坐标，含任务栏避让
        Left = wa.Right - Width - 4;
        Top = wa.Bottom - Height - 4;
        Show();
        Activate();
    }

    /// 预览模式：普通居中窗口，不自动隐藏（截图/演示用）。
    public void ShowCentered()
    {
        _pinned = true;
        var wa = SystemParameters.WorkArea;
        Left = wa.Left + (wa.Width - Width) / 2;
        Top = wa.Top + (wa.Height - Height) / 2;
        Show();
        Activate();
    }

    /// 自渲染截图（MYCO_SHOT，对齐 macOS 版）：把当前窗口输出成 PNG。
    public void Snapshot(string path)
    {
        var rtb = new System.Windows.Media.Imaging.RenderTargetBitmap(
            (int)(ActualWidth * 2), (int)(ActualHeight * 2), 192, 192,
            PixelFormats.Pbgra32);
        rtb.Render(this);
        var enc = new System.Windows.Media.Imaging.PngBitmapEncoder();
        enc.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(rtb));
        using var fs = System.IO.File.Create(path);
        enc.Save(fs);
    }

    // ---- 事件 ----

    private void OnToggleTheme(object sender, RoutedEventArgs e) => Theme.Toggle();

    private void OnTab(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string tab }) AppStore.I.SetTab(tab);
    }

    // ---- Tab 渲染 ----

    private object BuildTabContent(string key)
    {
        var (_, glyph, label) = _tabs.TryGetValue(key, out var t) ? t : (null!, "", key);
        var stack = new StackPanel { Margin = new Thickness(0, 4, 0, 4) };
        var icon = new TextBlock
        {
            Text = glyph, FontFamily = new FontFamily("Segoe MDL2 Assets"),
            FontSize = 15, HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center, Tag = "icon",
        };
        // 激活态 = 荧光青柠药丸包住图标（多巴胺 signature 的延伸）
        var pill = new Border
        {
            Width = 40, Height = 24, CornerRadius = new CornerRadius(12),
            HorizontalAlignment = HorizontalAlignment.Center,
            Background = Brushes.Transparent, Tag = "pill", Child = icon,
        };
        var text = new TextBlock
        {
            Text = label, FontSize = 9.5, FontWeight = FontWeights.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 3, 0, 0), Tag = "label",
        };
        stack.Children.Add(pill);
        stack.Children.Add(text);
        return stack;
    }

    private void UpdateTab()
    {
        foreach (var (key, (btn, _, _)) in _tabs)
        {
            var on = AppStore.I.Tab == key;
            if (btn.Content is not StackPanel stack) continue;
            foreach (var child in stack.Children)
            {
                switch (child)
                {
                    case Border pill:
                        if (on) pill.SetResourceReference(Border.BackgroundProperty, "BrandGrad");
                        else pill.Background = Brushes.Transparent;
                        if (pill.Child is TextBlock icon)
                            icon.SetResourceReference(TextBlock.ForegroundProperty, on ? "Ink" : "Text3");
                        break;
                    case TextBlock label:
                        label.SetResourceReference(TextBlock.ForegroundProperty, on ? "Brand" : "Text3");
                        break;
                }
            }
        }
        ContentHost.Content = ViewFor(AppStore.I.Tab);
    }

    private UserControl ViewFor(string tab)
    {
        if (_views.TryGetValue(tab, out var v)) return v;
        UserControl view = tab switch
        {
            "share" => new ShareView(),
            "relay" => new RelayView(),
            "history" => new HistoryView(),
            "settings" => new SettingsView(),
            _ => new HomeView(),
        };
        _views[tab] = view;
        return view;
    }
}
