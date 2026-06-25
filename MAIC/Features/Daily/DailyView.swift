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
                VStack(spacing: 0) {
                    prescriptionHero
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.top, Theme.Spacing.m)

                    Spacer().frame(height: 16)

                    statusCard
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.bottom, Theme.Spacing.l)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(backgroundWash)
            .navigationBarHidden(true)
            .fullScreenCover(item: $arSession) { session in
                ARAcupointView(session: session).environment(env)
            }
            .task { await loadInsights() }
        }
    }

    private var backgroundWash: some View {
        ZStack {
            Color(.systemBackground)
            Theme.softBrandGradient
                .frame(height: 260).frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
        }
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
                NavigationLink { ProfileView() } label: {
                    Circle().fill(Theme.brandGradient).frame(width: 38, height: 38)
                        .overlay(Text(String(env.profile.name.prefix(1)))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white))
                        .shadow(color: .white.opacity(0.25), radius: 6, y: 2)
                }
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
            // 標題列
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

            // 分隔線
            Divider().foregroundStyle(.tertiary).padding(.bottom, 12)

            if isLoadingInsights {
                VStack(spacing: 6) {
                    Spacer()
                    Text("載入中…")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let card = insights {
                cardBody(card)
            } else {
                VStack(spacing: 6) {
                    Spacer()
                    Text("點擊重新整理以載入")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
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
