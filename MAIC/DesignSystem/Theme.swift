import SwiftUI

enum Theme {
    /// 取自 App Icon 的青→藍漸層
    static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.373, green: 0.847, blue: 0.784),
            Color(red: 0.180, green: 0.486, blue: 0.769)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let softBrandGradient = LinearGradient(
        colors: [
            Color.accentColor.opacity(0.18),
            Color.accentColor.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    enum Spacing {
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 20
    }
}

extension View {
    func cardStyle(padding: CGFloat = Theme.Spacing.m) -> some View {
        self
            .padding(padding)
            .background(.regularMaterial,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}
