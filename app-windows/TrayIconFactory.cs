using System.Drawing;
using System.Drawing.Drawing2D;
using Microsoft.Win32;

namespace Myco;

/// 托盘图标：三层错位圆角方块（Myco「菌丝网络汇聚多 agent」隐喻），
/// GDI+ 绘制（对齐 macOS 版 TrayIcon.swift）。按任务栏深浅色自动反色。
public static class TrayIconFactory
{
    public static Icon Make()
    {
        // 任务栏用系统主题（SystemUsesLightTheme），浅色任务栏画黑、深色画白。
        var light = IsSystemLightTheme();
        var ink = light ? Color.Black : Color.White;

        const int s = 32;                       // 高 DPI 下托盘图标以 32px 绘制
        using var bmp = new Bitmap(s, s);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using var pen = new Pen(ink, 2.6f);
            using var fill = new SolidBrush(ink);

            void Chip(float x, float y, float size, bool filled)
            {
                using var path = Rounded(x, y, size, size, size * 0.28f);
                if (filled) g.FillPath(fill, path);
                else g.DrawPath(pen, path);
            }
            // 与 TrayIcon.swift 同构（y 轴翻转：GDI+ 原点在左上）：后两层描边、前一层实心。
            Chip(4.5f, 3.5f, 12.5f, false);
            Chip(11.5f, 7f, 12.5f, false);
            Chip(8f, 13f, 14.5f, true);
        }
        var h = bmp.GetHicon();
        // FromHandle 的句柄由我们负责——克隆成托管 Icon 后释放。
        using var tmp = Icon.FromHandle(h);
        var icon = (Icon)tmp.Clone();
        DestroyIcon(h);
        return icon;
    }

    private static GraphicsPath Rounded(float x, float y, float w, float h, float r)
    {
        var p = new GraphicsPath();
        p.AddArc(x, y, 2 * r, 2 * r, 180, 90);
        p.AddArc(x + w - 2 * r, y, 2 * r, 2 * r, 270, 90);
        p.AddArc(x + w - 2 * r, y + h - 2 * r, 2 * r, 2 * r, 0, 90);
        p.AddArc(x, y + h - 2 * r, 2 * r, 2 * r, 90, 90);
        p.CloseFigure();
        return p;
    }

    private static bool IsSystemLightTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("SystemUsesLightTheme") is int v && v != 0;
        }
        catch { return false; }
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool DestroyIcon(IntPtr handle);
}
