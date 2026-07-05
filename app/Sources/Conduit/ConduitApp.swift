import SwiftUI
import AppKit

// Conduit — one workspace, every agent.
// 纯菜单栏应用（LSUIElement）：NSStatusItem 托盘图标 + NSPopover 承载 SwiftUI 面板。
// 用 AppKit 承载而非原生 MenuBarExtra，是为了完全控制 popover 尺寸/圆角/材质，
// 精确复刻已定稿的 HTML 原型视觉。

@main
struct ConduitMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // 预览模式：用普通窗口展示面板，便于截图/演示；正常模式为纯菜单栏应用。
        if ProcessInfo.processInfo.environment["CONDUIT_PREVIEW"] != nil {
            app.setActivationPolicy(.regular)
        } else {
            app.setActivationPolicy(.accessory)   // 无 Dock 图标、无主窗口
        }
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var monitor: Any?
    let store = AppStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 托盘图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = TrayIcon.make()
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // 2. Popover 承载 SwiftUI 根视图
        popover.contentSize = NSSize(width: 396, height: 640)
        popover.behavior = .transient
        popover.animates = true
        let root = RootView().environmentObject(store)
        popover.contentViewController = NSHostingController(rootView: root)

        // 3. 首次启动异步检测本机 agent
        store.refresh()

        // 预览时可指定初始 tab（截图用）
        if let t = ProcessInfo.processInfo.environment["CONDUIT_TAB"],
           let tab = AppStore.Tab(rawValue: t) {
            store.tab = tab
        }

        // 预览模式：额外开一个普通窗口显示面板（便于截图/演示）
        if ProcessInfo.processInfo.environment["CONDUIT_PREVIEW"] != nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 396, height: 640),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isMovableByWindowBackground = true
            win.center()
            win.contentViewController = NSHostingController(
                rootView: RootView().environmentObject(store))
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            previewWindow = win

            // 自渲染截图：等 agent 异步检测 + 布局完成后，把根视图输出成 PNG。
            if let shot = ProcessInfo.processInfo.environment["CONDUIT_SHOT"] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    self.snapshot(view: win.contentView!, to: shot)
                    if ProcessInfo.processInfo.environment["CONDUIT_SHOT_QUIT"] != nil {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }

    private func snapshot(view: NSView, to path: String) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    private var previewWindow: NSWindow?

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        // 点击面板外部自动关闭
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
