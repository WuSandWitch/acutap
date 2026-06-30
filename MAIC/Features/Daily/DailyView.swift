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
    @State private var showProfile = false

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
                        Button { showProfile = true } label: {
                            Circle().fill(Theme.brandGradient).frame(width: 36, height: 36)
                                .overlay(Text(String(env.profile.name.prefix(1)))
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
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
        let pressCount = Int.random(in: 23...187)

        return VStack(alignment: .leading, spacing: 0) {
            // ── 天氣 ──
            HStack(spacing: 8) {
                Text(card.weatherTitle)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "humidity")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(card.humidityText)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 10)

            // ── 症狀 + 中醫解釋 ──
            VStack(alignment: .leading, spacing: 4) {
                Text(card.symptom)
                    .font(.subheadline.weight(.medium))
                Text(card.tcmExplanation)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 10)

            // ── 飲食 + 節氣 ──
            HStack(spacing: 16) {
                if !card.dietTip.isEmpty {
                    Label(card.dietTip, systemImage: "fork.knife")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if !card.seasonHint.isEmpty {
                    Spacer()
                    Label(card.seasonHint, systemImage: "sun.haze")
                        .font(.subheadline).foregroundStyle(.orange)
                }
            }
            .padding(.bottom, 14)

            // ── 穴位推薦（重點凸顯）──
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.teal.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "hand.point.up.fill")
                            .font(.title3).foregroundStyle(Theme.teal)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.acupointName)
                            .font(.subheadline.weight(.semibold))
                        Text(card.acupointReason)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(card.acupointId)
                        .font(.caption).foregroundStyle(.tertiary)
                }

                // 按壓人數
                HStack(spacing: 0) {
                    Spacer()
                    Text("今天已有 ")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(pressCount)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.teal)
                    Text(" 人按壓此穴")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(12)
            .background(Theme.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
    let weatherTitle: String
    let humidityText: String
    let symptom: String
    let tcmExplanation: String
    let acupointId: String
    let acupointName: String
    let acupointReason: String
    let dietTip: String
    let seasonHint: String
}
