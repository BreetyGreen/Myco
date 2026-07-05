import AppKit

/// 菜单栏托盘图标：三层错位圆角方块（Conduit「多 agent 汇聚」隐喻），
/// 绘成模板图像（随系统深浅自动反色）。
enum TrayIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        func chip(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, fill: Bool) {
            let r = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: s, height: s),
                                 xRadius: s * 0.28, yRadius: s * 0.28)
            r.lineWidth = 1.4
            if fill { r.fill() } else { r.stroke() }
        }
        // 后两层描边、前一层实心，形成层叠感
        chip(2.5, 8.5, 7, fill: false)
        chip(6.5, 6.5, 7, fill: false)
        chip(4.5, 2.5, 8, fill: true)

        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}
