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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    prescriptionHero
                    statusCard    // ← 取代舊的健康卡片+趨勢+AI
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

    // MARK: 今日點穴 (頭像在右上角)

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
                NavigationLink {
                    ProfileView()
                } label: {
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
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("看看狀態吧", systemImage: "sparkles.rectangle.stack")
                .font(.headline)
                .foregroundStyle(.primary)

            if isLoadingInsights {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("與中醫知識對話中…")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            } else if let card = insights {
                // ── 卡片主體 ──
                VStack(alignment: .leading, spacing: 0) {
                    // 頂部漸層條
                    cardTopBar(color: card.color)

                    // 內容
                    VStack(alignment: .leading, spacing: 16) {
                        // 狀態標題 + 簡短摘要
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle().fill(card.color.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: card.icon)
                                    .font(.title3).foregroundStyle(card.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.cardTitle)
                                    .font(.system(size: 20, weight: .bold))
                                Text(card.brief)
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }

                        // 中醫小知識 blurbs
                        if !card.tcmTip.isEmpty {
                            tipRow(icon: "leaf.fill", color: .green, title: "養生小知識", text: card.tcmTip)
                        }
                        if !card.tcmDetail.isEmpty {
                            tipRow(icon: "book.closed.fill", color: .orange, title: "中醫說", text: card.tcmDetail)
                        }

                        // 穴位推薦
                        if let ap = card.acupoint {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.point.up.fill")
                                    .font(.title3).foregroundStyle(Theme.teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("建議按壓 \(ap.name)（\(ap.id)）")
                                        .font(.subheadline.weight(.semibold))
                                    Text(ap.reason)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }

                        // 底部：飲食 + 節氣
                        HStack(spacing: 12) {
                            if !card.diet.isEmpty {
                                Label(card.diet, systemImage: "fork.knife")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if !card.seasonHint.isEmpty {
                                Label(card.seasonHint, systemImage: "sun.haze.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(Theme.Spacing.l)
                }
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            } else {
                // 尚未載入
                HStack {
                    Text("點擊載入今日中醫小知識")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Theme.teal)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                .onTapGesture { Task { await loadInsights() } }
            }
        }
    }

    private func tipRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline).foregroundStyle(color)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(color)
                Text(text).font(.subheadline).foregroundStyle(.primary)
            }
        }
        .padding(12)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func cardTopBar(color: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                Capsule().fill(color.opacity(0.3)).frame(height: 3)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
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
    let acupoint: InsightAcupoint?
    let diet: String
    let seasonHint: String

    struct InsightAcupoint: Codable {
        let id: String
        let name: String
        let reason: String
    }

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
