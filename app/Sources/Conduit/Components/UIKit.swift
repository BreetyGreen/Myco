import SwiftUI

// ============ 品牌 Logo（三层叠 chip）============
struct BrandMark: View {
    var size: CGFloat = 26
    @EnvironmentObject var store: AppStore
    var body: some View {
        let p = store.palette
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26)
                .strokeBorder(p.brand.opacity(0.55), lineWidth: 1.4)
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(x: -size * 0.14, y: -size * 0.16)
            RoundedRectangle(cornerRadius: size * 0.26)
                .strokeBorder(p.brandLite.opacity(0.6), lineWidth: 1.4)
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(x: size * 0.12, y: -size * 0.04)
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(LinearGradient(colors: [p.brandLite, p.brand2],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.7, height: size * 0.7)
                .offset(x: -size * 0.02, y: size * 0.14)
        }
        .frame(width: size, height: size)
    }
}

// ============ 眉标（eyebrow）============
struct Eyebrow: View {
    let text: String
    @EnvironmentObject var store: AppStore
    var body: some View {
        let p = store.palette
        HStack(spacing: 7) {
            Circle().fill(p.brand).frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(p.brand)
        }
    }
}

// ============ 双层斜面卡片 ============
struct BevelCard<Content: View>: View {
    @EnvironmentObject var store: AppStore
    var padding: CGFloat = 12
    @ViewBuilder var content: () -> Content
    var body: some View {
        let p = store.palette
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(p.card)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(p.lineSoft, lineWidth: 0.5))
            )
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(LinearGradient(colors: [p.line, p.lineSoft],
                                         startPoint: .top, endPoint: .bottom))
                    .padding(-1)
            )
    }
}

// ============ 主按钮 ============
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    @EnvironmentObject var store: AppStore
    @State private var pressed = false
    var body: some View {
        let p = store.palette
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(store.appearance == .dark ? Color(hex: "0B1408") : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(LinearGradient(colors: [p.brandLite, p.brand2],
                                         startPoint: .top, endPoint: .bottom))
            )
            .shadow(color: p.brandGlow, radius: pressed ? 6 : 12, y: pressed ? 3 : 8)
            .scaleEffect(pressed ? 0.985 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { v in
            withAnimation(.spring1) { pressed = v }
        }, perform: {})
    }
}

// ============ 次按钮 ============
struct GhostButton: View {
    let title: String
    let action: () -> Void
    @EnvironmentObject var store: AppStore
    var body: some View {
        let p = store.palette
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(p.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(p.card2)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(p.line, lineWidth: 0.5)))
        }
        .buttonStyle(.plain)
    }
}

// ============ 呼吸状态点 ============
struct LiveDot: View {
    var live: Bool
    @EnvironmentObject var store: AppStore
    @State private var pulse = false
    var body: some View {
        let p = store.palette
        Circle()
            .fill(live ? p.brand : p.text3.opacity(0.6))
            .frame(width: 7, height: 7)
            .overlay(
                Circle().stroke(p.brandGlow, lineWidth: live ? 4 : 0)
                    .scaleEffect(pulse ? 1.8 : 1)
                    .opacity(pulse ? 0 : 0.9)
            )
            .onAppear { if live { withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { pulse = true } } }
    }
}

// ============ 克制强调块（左侧品牌竖条）============
struct AccentNote<Content: View>: View {
    @EnvironmentObject var store: AppStore
    @ViewBuilder var content: () -> Content
    var body: some View {
        let p = store.palette
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(p.brand).frame(width: 3)
            content()
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 11).fill(p.card2))
    }
}
