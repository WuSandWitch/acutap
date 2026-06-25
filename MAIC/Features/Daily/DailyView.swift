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

                    Spacer().frame(height: Theme.Spacing.l)

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
                .frame(height: 280).frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
        }
    }

    // MARK: 今日點穴

    private var prescriptionHero: some View {
        let p = env.todaysPrescription
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日點穴")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                    Text(p.title)
                        .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                    Text(p.rationale)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                NavigationLink { ProfileView() } label: {
                    Circle().fill(Theme.brandGradient).frame(width: 42, height: 42)
                        .overlay(Text(String(env.profile.name.prefix(1)))
                            .font(.headline).foregroundStyle(.white))
                        .shadow(color: .white.opacity(0.3), radius: 8, y: 3)
                }
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
                    Text("\(p.totalSeconds)s").font(.subheadline.monospacedDigit()).opacity(0.6)
                    Image(systemName: "arrow.right")
                }
                .font(.headline).foregroundStyle(Theme.ocean)
                .padding(.vertical, 16).padding(.horizontal, 20)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(Theme.Spacing.l)
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

    // MARK: 🎴 看看狀態吧

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline).foregroundStyle(Theme.teal)
                Text("看看狀態吧")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoadingInsights {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .foregroundStyle(.primary)

            if isLoadingInsights {
                Spacer()
                HStack {
                    Spacer()
                    Text("載入中…")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else if let card = insights {
                cardBody(card)
            } else {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Theme.teal)
                        Text("點擊載入")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .onTapGesture { Task { await loadInsights() } }
                Spacer()
            }
        }
        .padding(Theme.Spacing.l)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func cardBody(_ card: HealthInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 狀態摘要
            HStack(spacing: 10) {
                Image(systemName: card.icon)
                    .font(.title3).foregroundStyle(card.color)
                Text(card.cardTitle)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text(card.brief)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            Divider().foregroundStyle(.tertiary)

            // 養生小知識
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "leaf")
                    .font(.caption).foregroundStyle(.green)
                Text(card.tcmTip)
                    .font(.subheadline)
            }

            // 中醫說
            if !card.tcmDetail.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.book.closed")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(card.tcmDetail)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // 飲食 + 節氣
            HStack(spacing: 16) {
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

    var icon: String {
        switch statusColor {
        case "green": "heart.fill"
        case "orange": "exclamationmark.triangle.fill"
        case "red": "xmark.octagon.fill"
        default: "sparkles"
        }
    }
}
