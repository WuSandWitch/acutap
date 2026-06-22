import SwiftUI

// MARK: - 按壓回饋（全 App 通用）

/// 輕微縮放 + 透明度的彈性按壓樣式
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

// MARK: - 主要 CTA 按鈕

struct GlowButton: View {
    let title: String
    var systemImage: String? = nil
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                }
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline.monospacedDigit())
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.brandGradient, in: Capsule())
            .shadow(color: Theme.teal.opacity(0.45), radius: 16, y: 8)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - 區段標題

struct SectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.teal)
            }
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
    }
}

// MARK: - 標籤膠囊

struct PillTag: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = Theme.teal

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.semibold))
            }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.15), in: Capsule())
        .foregroundStyle(tint)
    }
}

// MARK: - 可選 Chip（AI 快捷選項）

struct ChoiceChip: View {
    let text: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.semibold))
                }
                Text(text).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : Theme.teal)
            .background {
                if isSelected {
                    Capsule().fill(Theme.brandGradient)
                } else {
                    Capsule().fill(Theme.teal.opacity(0.12))
                }
            }
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - 倒數計時環

struct RingTimer: View {
    let progress: Double      // 0...1
    let label: String
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Theme.brandGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
                .shadow(color: Theme.teal.opacity(0.4), radius: 6)
            Text(label)
                .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 呼吸式發光點（穴位視覺核心）

struct BreathingDot: View {
    var color: Color = Theme.aqua
    var size: CGFloat = 26
    var labelInitial: String? = nil
    @State private var pulse = false

    var body: some View {
        ZStack {
            // 外層擴散光環
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: size * 1.9, height: size * 1.9)
                .scaleEffect(pulse ? 1.4 : 0.85)
                .opacity(pulse ? 0 : 0.7)
            // 核心點
            Circle()
                .fill(Theme.brandGradient)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 2))
                .shadow(color: color.opacity(0.7), radius: 8)
            if let labelInitial {
                Text(labelInitial)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - 動畫數值（健康指標）

struct AnimatedMetric: View {
    let value: Int
    var font: Font = .system(.title2, design: .rounded).weight(.semibold)

    var body: some View {
        Text("\(value)")
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
    }
}

// MARK: - 進場過場修飾（由下淡入）

struct RiseIn: ViewModifier {
    let delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(Theme.Motion.smooth.delay(delay)) { shown = true }
            }
    }
}

extension View {
    /// 進場時由下淡入，delay 可做交錯動畫
    func riseIn(delay: Double = 0) -> some View { modifier(RiseIn(delay: delay)) }
}
