import SwiftUI

/// 穴新達 AcuTap! 設計系統 —— 取色自 App Icon 的青→藍漸層。
enum Theme {

    // MARK: - Brand colors (取自 App Icon)
    static let aqua  = Color(red: 0.42, green: 0.85, blue: 0.83)   // #6BD9D4 亮青
    static let teal  = Color(red: 0.18, green: 0.66, blue: 0.74)   // #2EA9BD
    static let ocean = Color(red: 0.16, green: 0.45, blue: 0.72)   // #2972B8 深藍
    static let deep  = Color(red: 0.10, green: 0.30, blue: 0.55)   // #1A4D8C

    // MARK: - Gradients
    /// 主品牌漸層（CTA、發光、Hero 卡）
    static let brandGradient = LinearGradient(
        colors: [aqua, teal, ocean],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Hero 用更飽和的對角漸層
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.40, green: 0.82, blue: 0.80),
            Color(red: 0.16, green: 0.55, blue: 0.74),
            Color(red: 0.13, green: 0.36, blue: 0.62)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 背景柔光（淡淡品牌色暈染）
    static let softBrandGradient = LinearGradient(
        colors: [aqua.opacity(0.16), ocean.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 穴位發光的徑向漸層
    static let glowGradient = RadialGradient(
        colors: [aqua.opacity(0.9), teal.opacity(0.0)],
        center: .center, startRadius: 1, endRadius: 26
    )

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Radius
    enum Radius {
        static let card: CGFloat = 24
        static let tile: CGFloat = 18
        static let pill: CGFloat = 999
    }

    // MARK: - Motion（統一的彈簧曲線）
    enum Motion {
        static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
        static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.72)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.62)
        static let gentle = Animation.easeInOut(duration: 0.6)
    }
}

// MARK: - 卡片樣式

extension View {
    /// 標準毛玻璃卡片
    func cardStyle(padding: CGFloat = Theme.Spacing.m,
                   radius: CGFloat = Theme.Radius.card) -> some View {
        self
            .padding(padding)
            .background(.regularMaterial,
                        in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}
