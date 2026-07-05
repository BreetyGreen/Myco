import SwiftUI

// 从 HTML 原型精修版平移的墨绿品牌体系（skillshare → Conduit）。
// 官方 token：#16171D 墨黑 / #639922 品牌绿 / #3B6D11 深绿 /
//            #C0DD97 #EAF3DE 浅绿 / #5F5E5A 暖灰。

extension Color {
    init(hex: String, alpha: Double = 1) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8) / 255
        let b = Double(v & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum Appearance: String { case dark, light }

/// 语义化调色板，随主题切换。所有值对齐 HTML 原型的 CSS 变量。
struct Palette {
    let appearance: Appearance

    // 壁纸渐变
    var wallA: Color { appearance == .dark ? Color(hex: "0B1408") : Color(hex: "E6EEDD") }
    var wallB: Color { appearance == .dark ? Color(hex: "0C0D11") : Color(hex: "EFF2EA") }
    var wallC: Color { appearance == .dark ? Color(hex: "111721") : Color(hex: "E3EAF2") }

    // 面板玻璃
    var panelTop: Color { appearance == .dark ? Color(hex: "1C1E26", alpha: 0.86) : Color(hex: "FFFFFF", alpha: 0.92) }
    var panelBot: Color { appearance == .dark ? Color(hex: "121319", alpha: 0.90) : Color(hex: "F8FAF5", alpha: 0.92) }
    var panelLine: Color { appearance == .dark ? Color(hex: "FFFFFF", alpha: 0.08) : Color(hex: "16171D", alpha: 0.09) }
    var menubar: Color { appearance == .dark ? Color(hex: "101117", alpha: 0.72) : Color(hex: "FFFFFF", alpha: 0.70) }

    // 卡片 / 分隔
    var card: Color { appearance == .dark ? Color(hex: "FFFFFF", alpha: 0.045) : Color(hex: "16171D", alpha: 0.032) }
    var card2: Color { appearance == .dark ? Color(hex: "FFFFFF", alpha: 0.028) : Color(hex: "16171D", alpha: 0.02) }
    var line: Color { appearance == .dark ? Color(hex: "FFFFFF", alpha: 0.09) : Color(hex: "16171D", alpha: 0.10) }
    var lineSoft: Color { appearance == .dark ? Color(hex: "FFFFFF", alpha: 0.055) : Color(hex: "16171D", alpha: 0.06) }

    // 文本三级
    var text: Color { appearance == .dark ? Color(hex: "E9EDE3") : Color(hex: "16171D") }
    var text2: Color { appearance == .dark ? Color(hex: "9BA394") : Color(hex: "5F5E5A") }
    var text3: Color { appearance == .dark ? Color(hex: "6A7164") : Color(hex: "8A897F") }

    // 品牌绿阶梯
    var brand: Color { appearance == .dark ? Color(hex: "8FCB4E") : Color(hex: "4E7D18") }   // 主 accent（深色下提亮）
    var brand2: Color { Color(hex: "639922") }        // 官方绿
    var brandDeep: Color { Color(hex: "3B6D11") }     // 深绿
    var brandLite: Color { appearance == .dark ? Color(hex: "C0DD97") : Color(hex: "7FB03A") }
    var inkLite: Color { appearance == .dark ? Color(hex: "EAF3DE") : Color(hex: "2C4A0E") }
    var brandGlow: Color { appearance == .dark ? Color(hex: "7CB342", alpha: 0.45) : Color(hex: "639922", alpha: 0.34) }
    var brandTint: Color { appearance == .dark ? Color(hex: "7CB342", alpha: 0.14) : Color(hex: "639922", alpha: 0.10) }

    var danger: Color { appearance == .dark ? Color(hex: "FF6B5E") : Color(hex: "E5484D") }
    var warn: Color { appearance == .dark ? Color(hex: "F0A93B") : Color(hex: "D98324") }

    // Agent 品牌色
    var claude: Color { appearance == .dark ? Color(hex: "D97757") : Color(hex: "C15F3C") }
    var workbuddy: Color { appearance == .dark ? Color(hex: "7C7BE8") : Color(hex: "5B5BD6") }
    var codex: Color { appearance == .dark ? Color(hex: "E9EDE3") : Color(hex: "16171D") }
    var cursor: Color { appearance == .dark ? Color(hex: "9AA0A9") : Color(hex: "55585F") }
    var antigravity: Color { appearance == .dark ? Color(hex: "22C3E6") : Color(hex: "0891B2") }

    func agentColor(_ id: AgentID) -> Color {
        switch id {
        case .claude: return claude
        case .workbuddy: return workbuddy
        case .codex: return codex
        case .cursor: return cursor
        case .antigravity: return antigravity
        }
    }
}

/// 全局可观察的主题 + 应用状态入口在 AppStore 里；这里只暴露调色板便利。
struct ThemeKey: EnvironmentKey {
    static let defaultValue = Palette(appearance: .dark)
}
extension EnvironmentValues {
    var palette: Palette {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// 弹簧动画常量，复刻 HTML 的 cubic-bezier(.32,.72,0,1)
extension Animation {
    static var spring1: Animation { .spring(response: 0.42, dampingFraction: 0.78) }
    static var springSoft: Animation { .spring(response: 0.5, dampingFraction: 0.85) }
    static var easeQuick: Animation { .easeOut(duration: 0.25) }
}
