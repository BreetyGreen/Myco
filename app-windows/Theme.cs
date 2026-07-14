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
        r["Text"]  = B(dark ? "#F0F3E9" : "#1C1E13");
        r["Text2"] = B(dark ? "#A9B09D" : "#60644F");
        r["Text3"] = B(dark ? "#767D6B" : "#90947F");

        // 品牌绿：多巴胺荧光青柠（深色下做点缀高亮，浅色下压深保证对比度）
        r["Brand"]     = B(dark ? "#C9F45D" : "#5A8A1D");
        r["Brand2"]    = B("#639922");
        r["BrandLite"] = B(dark ? "#E3FA9F" : "#A6D95B");
        r["BrandGlow"] = B(dark ? "#C9F45D" : "#639922", dark ? 0.35 : 0.30);
        r["BrandTint"] = B(dark ? "#C9F45D" : "#639922", dark ? 0.13 : 0.10);
        r["Warn"]      = B(dark ? "#F0A93B" : "#D98324");

        // 卡片改实色（多巴胺风：卡片有分量，背景干净）
        r["Card"]     = dark ? B("#1C1F16") : B("#FFFFFF");
        r["Card2"]    = B(dark ? "#FFFFFF" : "#16171D", dark ? 0.035 : 0.03);
        r["Line"]     = B(dark ? "#FFFFFF" : "#16171D", dark ? 0.07 : 0.09);
        r["LineSoft"] = B(dark ? "#FFFFFF" : "#16171D", dark ? 0.045 : 0.055);

        // 背景：近黑炭（微绿暖）/ 奶油灰，弱化渐变，让荧光主卡成为唯一亮点
        r["WallGrad"] = Grad(45,
            dark ? "#14170C" : "#F2F1E9",
            dark ? "#101207" : "#EEEFE6",
            dark ? "#121313" : "#E9ECE0");
        r["PanelGrad"] = Grad(90,
            dark ? "#CC181B0F" : "#99FFFFFF",   // 顶部（带透明度的 ARGB）
            dark ? "#E60F1108" : "#CCFAFBF4");  // 底部

        // 荧光青柠渐变：主按钮 / 首页 hero 卡 / 激活 tab 药丸共用（signature）
        r["BrandGrad"] = Grad(45,
            dark ? "#DCF87E" : "#D8F471",
            dark ? "#A6E14F" : "#9BD644",
            dark ? "#64AC28" : "#6FB52D");
        // 压在荧光绿上的墨字（两个主题一致：亮绿配深墨，对齐参考稿）
        r["Ink"]       = B("#1A2408");
        r["InkSoft"]   = B("#1A2408", 0.62);
        r["PrimaryFg"] = B("#1A2408");

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
