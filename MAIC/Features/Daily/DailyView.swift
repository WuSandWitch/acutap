import SwiftUI

struct DailyView: View {
    var goToAR: () -> Void = {}

    @Environment(AppEnvironment.self) private var env
    @State private var arSession: PointSession?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header.riseIn(delay: 0)
                    prescriptionHero.riseIn(delay: 0.08)
                    quickReliefSection.riseIn(delay: 0.16)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(backgroundWash)
            .navigationBarHidden(true)
            .fullScreenCover(item: $arSession) { session in
                ARAcupointView(session: session).environment(env)
            }
        }
    }

    private var backgroundWash: some View {
        ZStack {
            Color(.systemBackground)
            Theme.softBrandGradient
                .frame(height: 320)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
        }
    }

    // MARK: Header（問候 + 頭像）

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting)，\(env.profile.name)")
                    .font(.largeTitle.weight(.bold))
                Text(Date.now, format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink {
                ProfileView()
            } label: {
                Circle().fill(Theme.brandGradient)
                    .frame(width: 42, height: 42)
                    .overlay(Text(String(env.profile.name.prefix(1)))
                        .font(.headline).foregroundStyle(.white))
                    .shadow(color: Theme.teal.opacity(0.35), radius: 8, y: 3)
            }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: "早安"
        case 11..<14: "午安"
        case 14..<18: "午後好"
        default: "晚安"
        }
    }

    // MARK: 今日點穴主卡（唯一焦點）

    private var prescriptionHero: some View {
        let p = env.todaysPrescription
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日點穴")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(p.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Text(p.rationale)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                ForEach(p.acupoints) { a in
                    Text(a.nameZh)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(.white.opacity(0.2), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                arSession = env.dailySession
            } label: {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("開始 AR 點穴")
                    Spacer()
                    Text("\(p.totalSeconds)s")
                        .font(.subheadline.monospacedDigit()).opacity(0.6)
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(Theme.ocean)
                .padding(.vertical, 16).padding(.horizontal, 20)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Theme.heroGradient
                Circle().fill(.white.opacity(0.12)).frame(width: 240)
                    .offset(x: 130, y: -110).blur(radius: 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.ocean.opacity(0.28), radius: 24, y: 12)
    }

    // MARK: 依部位快速點穴

    private var quickReliefSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("依部位快速點穴")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.m) {
                    ForEach(BodyRegion.allCases) { region in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            arSession = PointSession(
                                title: "\(region.displayName) · 舒緩",
                                subtitle: region.symptomHint,
                                acupoints: env.data.acupoints(ids: region.acupointIDs))
                        } label: {
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(Theme.teal.opacity(0.12)).frame(width: 60, height: 60)
                                    Image(systemName: region.symbol)
                                        .font(.title3).foregroundStyle(Theme.teal)
                                }
                                Text(region.displayName)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
