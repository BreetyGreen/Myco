using System.Runtime.InteropServices;

namespace Myco;

/// Win11 原生 Acrylic 亚克力背板（DWM 系统 backdrop）：
/// 真·背景模糊，对齐 macOS 版 NSPopover 的 hudWindow 毛玻璃材质。
/// 需要 Win11 22H2+（build 22621）；失败时返回 false，调用方回退为不透明背景。
public static class GlassHelper
{
    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;   // 深色 acrylic 基调
    private const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;  // DWMWCP_ROUND = 2
    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;       // DWMSBT_TRANSIENTWINDOW = 3

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    public static bool Apply(IntPtr hwnd, bool dark)
    {
        var darkMode = dark ? 1 : 0;
        DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, ref darkMode, 4);

        var round = 2;
        DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, ref round, 4);

        var acrylic = 3;   // TRANSIENTWINDOW：弹出面板专用的 acrylic
        return DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ref acrylic, 4) == 0;
    }
}
