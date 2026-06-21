import SwiftUI

/// 身體區域 — 對應到一組穴位
enum BodyRegion: String, CaseIterable, Identifiable {
    case head, neckShoulder, chest, abdomen, arm, leg
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .head: "頭部"
        case .neckShoulder: "頸肩"
        case .chest: "胸口"
        case .abdomen: "腹部"
        case .arm: "手部"
        case .leg: "腿足"
        }
    }

    var symptomHint: String {
        switch self {
        case .head: "頭痛、頭暈、提神醒腦"
        case .neckShoulder: "肩頸僵硬、落枕"
        case .chest: "胸悶、心悸、氣短"
        case .abdomen: "脹氣、消化不良、經痛"
        case .arm: "手痠、滑鼠手、安神"
        case .leg: "腿痠、疲倦、助眠"
        }
    }

    /// 對應穴位 ID（與 MockDataProvider 一致）
    var acupointIDs: [String] {
        switch self {
        case .head: ["GV20", "GB20"]
        case .neckShoulder: ["GB21", "GB20", "LI4"]
        case .chest: ["CV17", "PC6", "LU7"]
        case .abdomen: ["ST36", "SP6"]
        case .arm: ["PC6", "HT7", "LI4"]
        case .leg: ["ST36", "SP6", "LV3", "BL23"]
        }
    }

    /// 在人體圖上的相對座標（0…1），用於 hot zone 圓圈位置。
    /// 圖片為「正面 + 背面」並排，左半為正面（x≈0…0.5），右半為背面（x≈0.5…1）。
    var hotZone: (x: Double, y: Double) {
        switch self {
        case .head:         (0.27, 0.11)   // 正面 頭部
        case .neckShoulder: (0.72, 0.22)   // 背面 肩頸
        case .chest:        (0.27, 0.28)   // 正面 胸口
        case .abdomen:      (0.27, 0.40)   // 正面 腹部
        case .arm:          (0.14, 0.42)   // 正面 手臂
        case .leg:          (0.30, 0.72)   // 正面 腿足
        }
    }
}

struct BodyTapView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selected: BodyRegion?
    @State private var showAR = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                bodyCanvas
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .sheet(item: $selected) { region in
                RegionDetailSheet(region: region)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showAR) { ARPlaceholderView() }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("哪裡不舒服？")
                    .font(.title.weight(.bold))
                Text("點擊身體部位，AI 會告訴你該按哪裡")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showAR = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "visionpro")
                    Text("AR")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Theme.brandGradient, in: Capsule())
                .foregroundStyle(.white)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.s)
    }

    private var bodyCanvas: some View {
        VStack(spacing: 0) {
            Image("BodyDiagram")
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { geo in
                        ForEach(BodyRegion.allCases) { region in
                            HotZone(region: region, isSelected: selected == region) {
                                selected = region
                            }
                            .position(x: region.hotZone.x * geo.size.width,
                                      y: region.hotZone.y * geo.size.height)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)

            HStack {
                figureLabel("正面")
                figureLabel("背面")
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.m)
        }
    }

    private func figureLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Hot zone

private struct HotZone: View {
    let region: BodyRegion
    let isSelected: Bool
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.25))
                    .frame(width: 48, height: 48)
                    .scaleEffect(pulse ? 1.35 : 1.0)
                    .opacity(pulse ? 0 : 0.8)
                Circle()
                    .fill(Theme.brandGradient)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 2))
                    .shadow(color: Color.accentColor.opacity(0.55), radius: 6, y: 2)
                Text(region.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Region detail sheet

private struct RegionDetailSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let region: BodyRegion
    @State private var startPractice = false

    private var acupoints: [Acupoint] {
        region.acupointIDs.compactMap { id in
            env.data.allAcupoints.first(where: { $0.id == id })
        }
    }

    private var prescription: Prescription {
        Prescription(
            id: UUID(),
            date: Date(),
            title: "\(region.displayName) · 舒緩",
            rationale: region.symptomHint,
            acupoints: acupoints
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(region.displayName)
                            .font(.largeTitle.weight(.bold))
                        Text(region.symptomHint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(acupoints.enumerated()), id: \.element.id) { idx, a in
                            acupointRow(index: idx + 1, a: a)
                        }
                    }

                    Button {
                        startPractice = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("開始按摩")
                                .font(.title3.weight(.bold))
                            Text("· \(prescription.totalSeconds)s")
                                .font(.subheadline.monospacedDigit())
                                .opacity(0.85)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.brandGradient, in: Capsule())
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 14, y: 6)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .navigationDestination(isPresented: $startPractice) {
                PracticeView(prescription: prescription)
            }
        }
    }

    private func acupointRow(index: Int, a: Acupoint) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.14))
                Text("\(index)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(a.nameZh).font(.headline)
                    Text(a.id).font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(a.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Text("\(a.pressSeconds)s")
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
