import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let p = store.palette
        VStack(spacing: 0) {
            header
            Divider().overlay(p.lineSoft)
            content
            tabbar
        }
        .frame(width: 396, height: 640)
        .background(background)
        .environment(\.palette, p)
        .preferredColorScheme(store.appearance == .dark ? .dark : .light)
    }

    // 玻璃 + 壁纸背景
    private var background: some View {
        let p = store.palette
        return ZStack {
            LinearGradient(colors: [p.wallA, p.wallB, p.wallC],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VisualEffectBackground()
                .opacity(store.appearance == .dark ? 0.5 : 0.7)
            LinearGradient(colors: [p.panelTop, p.panelBot],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    // 品牌头
    private var header: some View {
        let p = store.palette
        return HStack(spacing: 9) {
            BrandMark(size: 26)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 0) {
                    Text("con").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(p.text)
                    Text("duit").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(p.brand)
                }
                Text("one workspace, every agent")
                    .font(.system(size: 10.5)).tracking(0.3)
                    .foregroundColor(p.text3)
            }
            Spacer()
            // 主题切换
            Button(action: { store.toggleTheme() }) {
                Image(systemName: store.appearance == .dark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(p.text2)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(p.card2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14).padding(.bottom, 12)
    }

    // 内容区（随 tab 切换）
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch store.tab {
                case .home: HomeView()
                case .share: ShareView()
                case .relay: RelayView()
                case .history: HistoryView()
                case .settings: SettingsView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .transition(.opacity)
    }

    // 底部 Tab
    private var tabbar: some View {
        let p = store.palette
        return HStack(spacing: 4) {
            tabItem(.home, "square.grid.2x2", "总览")
            tabItem(.share, "square.stack.3d.up", "共享")
            tabItem(.relay, "arrow.left.arrow.right", "接力")
            tabItem(.history, "clock.arrow.circlepath", "历史")
            tabItem(.settings, "gearshape", "设置")
        }
        .padding(.horizontal, 10)
        .padding(.top, 8).padding(.bottom, 10)
        .background(
            VStack(spacing: 0) {
                Divider().overlay(p.lineSoft)
                Rectangle().fill(p.card2).frame(height: 60)
            }
        )
    }

    private func tabItem(_ t: AppStore.Tab, _ icon: String, _ label: String) -> some View {
        let p = store.palette
        let on = store.tab == t
        return Button(action: { withAnimation(.spring1) { store.tab = t } }) {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(on ? p.brand : .clear)
                    .frame(width: 16, height: 2)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: on ? .semibold : .regular))
                Text(label).font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundColor(on ? p.brand : p.text3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// NSVisualEffectView 桥接（毛玻璃材质）
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
