//
//  DailyView.swift
//  MAIC
//

import SwiftUI

struct DailyView: View {
    var goToAR: () -> Void = {}

    @Environment(AppEnvironment.self) private var env
    @State private var arSession: PointSession?
    @State private var insights: HealthInsights?
    @State private var isLoadingInsights = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let topInset = geo.safeAreaInsets.top
                let headerHeight: CGFloat = 40  // Hello + 頭像
                let heroHeight: CGFloat = 260
                let spacing: CGFloat = 14
                let bottomPadding: CGFloat = Theme.Spacing.l
                let cardHeight = geo.size.height - headerHeight - heroHeight - spacing - bottomPadding - topInset - 8

                VStack(spacing: 0) {
                    // Hello + 頭像
                    HStack {
                        Text("Hello, \(env.profile.name)!")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        NavigationLink {
                            ProfileView()
                        } label: {
                            Circle().fill(Theme.brandGradient).frame(width: 36, height: 36)
                                .overlay(Text(String(env.profile.name.prefix(1)))
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)  // 增加點擊區域
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.m)

                    Spacer().frame(height: spacing)

                    prescriptionHero
                        .padding(.horizontal, Theme.Spacing.l)

                    Spacer().frame(height: spacing)

                    statusCard
                        .frame(height: max(cardHeight, 160))
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.bottom, bottomPadding)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .fullScreenCover(item: $arSession) { session in
                ARAcupointView(session: session).environment(env)
            }
        }
        .task { await loadInsights() }
    }

    // MARK: 今日點穴

    private var prescriptionHero: some View {
        let p = env.todaysPrescription
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日點穴")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                    Text(p.title)
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                    Text(p.rationale)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            HStack(spacing: 5) {
                ForEach(p.acupoints) { a in
                    Text(a.nameZh)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.18), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                arSession = env.dailySession
            } label: {
                HStack {
                    Image(systemName: "camera.viewfinder").font(.subheadline)
                    Text("開始 AR 點穴").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(p.totalSeconds)s")
                        .font(.caption.monospacedDigit()).opacity(0.6)
                    Image(systemName: "chevron.right").font(.caption)
                }
                .foregroundStyle(Theme.ocean)
                .padding(.vertical, 14).padding(.horizontal, 18)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(Theme.Spacing.l)
        .background {
            ZStack {
                Theme.heroGradient
                Circle().fill(.white.opacity(0.1)).frame(width: 200)
                    .offset(x: 120, y: -100).blur(radius: 5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Theme.ocean.opacity(0.2), radius: 18, y: 10)
    }

    // MARK: 🎴 看看狀態吧

    private var statusCard: some View {
        VStack(spacing: 0) {
            // 標題列（固定）
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.caption).foregroundStyle(Theme.teal)
                Text("看看狀態吧")
                    .font(.caption.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                if isLoadingInsights {
                    ProgressView().scaleEffect(0.65)
                } else if insights == nil {
                    Button { Task { await loadInsights() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption).foregroundStyle(Theme.teal)
                    }
                }
            }
            .padding(.bottom, 12)

            Divider().foregroundStyle(.tertiary).padding(.bottom, 12)

            // 內容區（固定高度內填滿）
            if isLoadingInsights {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
                        Text("載入中…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if let card = insights {
                cardBody(card)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Spacer()
                HStack {
                    Spacer()
                    Text("點擊重新整理以載入")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
    }

    private func cardBody(_ card: HealthInsights) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 狀態
            HStack(spacing: 8) {
                Circle().fill(card.color).frame(width: 8, height: 8)
                Text(card.cardTitle)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(card.brief)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            // 養生小知識
            if !card.tcmTip.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "leaf")
                        .font(.caption).foregroundStyle(.green)
                    Text(card.tcmTip)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 中醫說
            if !card.tcmDetail.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.book.closed")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(card.tcmDetail)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 底部：飲食 + 節氣
            if !card.diet.isEmpty || !card.seasonHint.isEmpty {
                Divider().foregroundStyle(.tertiary)
                HStack(spacing: 12) {
                    if !card.diet.isEmpty {
                        Label(card.diet, systemImage: "fork.knife")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !card.seasonHint.isEmpty {
                        Label(card.seasonHint, systemImage: "sun.haze")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    // MARK: Load

    private func loadInsights() async {
        isLoadingInsights = true
        insights = await env.fetchHealthInsights()
        isLoadingInsights = false
    }
}

// MARK: - Insights Model

struct HealthInsights: Codable {
    let cardTitle: String
    let statusColor: String
    let brief: String
    let tcmTip: String
    let tcmDetail: String
    let diet: String
    let seasonHint: String

    var color: Color {
        switch statusColor {
        case "green": .green
        case "orange": .orange
        case "red": .red
        default: Theme.teal
        }
    }
}
