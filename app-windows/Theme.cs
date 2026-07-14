using System.Windows;
using System.Windows.Media;

namespace Myco;

/// 墨绿品牌调色板，逐色对齐 macOS 版 app/Sources/Myco/Theme.swift。
/// 所有颜色注册为 Application 资源，视图用 DynamicResource 引用，
/// 切换主题 = 重写资源值，界面自动刷新。
public static class Theme
{
    public static bool Dark { get; private set; } = true;
    public static event Action? Changed;

    public static void Toggle() => Apply(!Dark);

    public static void Apply(bool dark)
    {
        Dark = dark;
        var r = Application.Current.Resources;

        // 文本三级
        r["Text"]  = B(dark ? "#E9EDE3" : "#16171D");
        r["Text2"] = B(dark ? "#9BA394" : "#5F5E5A");
        r["Text3"] = B(dark ? "#6A7164" : "#8A897F");

        // 品牌绿阶梯
        r["Brand"]     = B(dark ? "#8FCB4E" : "#4E7D18");
        r["Brand2"]    = B("#639922");
        r["BrandLite"] = B(dark ? "#C0DD97" : "#7FB03A");
        r["BrandGlow"] = B(dark ? "#7CB342" : "#639922", dark ? 0.45 : 0.34);
        r["BrandTint"] = B(dark ? "#7CB342" : "#639922", dark ? 0.14 : 0.10);
        r["Warn"]      = B(dark ? "#F0A93B" : "#D98324");

        // 卡片 / 分隔
        r["Card"]     = B(dark ? "#FFFFFF" : "#16171D", dark ? 0.045 : 0.032);
        r["Card2"]    = B(dark ? "#FFFFFF" : "#16171D", dark ? 0.028 : 0.02);
        r["Line"]     = B(dark ? "#FFFFFF" : "#16171D", dark ? 0.09 : 0.10);
        r["LineSoft"] = B(dark ? "#FFFFFF" : "#16171D", dark ? 0.055 : 0.06);

        // 壁纸渐变 + 面板玻璃（Windows 不做毛玻璃，用等价纯色渐变叠加）
        r["WallGrad"] = Grad(45,
            dark ? "#0B1408" : "#E6EEDD",
            dark ? "#0C0D11" : "#EFF2EA",
            dark ? "#111721" : "#E3EAF2");
        r["PanelGrad"] = Grad(90,
            dark ? "#DB1C1E26" : "#EBFFFFFF",   // panelTop（带透明度的 ARGB）
            dark ? "#E6121319" : "#EBF8FAF5");  // panelBot

        // 主按钮（brandLite → brand2 渐变；前景深色下用墨黑）
        r["BrandGrad"] = Grad(90, dark ? "#C0DD97" : "#7FB03A", "#639922");
        r["PrimaryFg"] = B(dark ? "#0B1408" : "#FFFFFF");

        Changed?.Invoke();
    }

    /// Agent 品牌色（对齐 Theme.swift；未知 id 给中性灰）。
    public static Brush AgentColor(string id) => id switch
    {
        "claude"      => B(Dark ? "#D97757" : "#C15F3C"),
        "workbuddy"   => B(Dark ? "#7C7BE8" : "#5B5BD6"),
        "codex"       => B(Dark ? "#3A3F35" : "#16171D"),
        "cursor"      => B(Dark ? "#9AA0A9" : "#55585F"),
        "antigravity" => B(Dark ? "#22C3E6" : "#0891B2"),
        _             => B(Dark ? "#6A7164" : "#8A897F"),
    };

    private static SolidColorBrush B(string hex, double alpha = 1)
    {
        var c = (Color)ColorConverter.ConvertFromString(hex);
        if (alpha < 1) c.A = (byte)(alpha * 255);
        var b = new SolidColorBrush(c);
        b.Freeze();
        return b;
    }

    private static LinearGradientBrush Grad(double angle, params string[] hexes)
    {
        var g = new LinearGradientBrush { StartPoint = new Point(0, 0), EndPoint = new Point(0, 1) };
        if (angle != 90) { g.StartPoint = new Point(0, 0); g.EndPoint = new Point(1, 1); }
        for (var i = 0; i < hexes.Length; i++)
        {
            var c = (Color)ColorConverter.ConvertFromString(hexes[i]);
            g.GradientStops.Add(new GradientStop(c, hexes.Length == 1 ? 0 : (double)i / (hexes.Length - 1)));
        }
        g.Freeze();
        return g;
    }
}
