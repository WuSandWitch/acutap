import SwiftUI
import Charts

struct DailyView: View {
    var goToAR: () -> Void = {}

    @Environment(AppEnvironment.self) private var env
    @State private var arSession: PointSession?
    @State private var showAIAnalysis = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    prescriptionHero
                    healthMetricsRow
                    if !(env.healthMetrics.isEmpty) { weeklyTrend }
                    aiRecommendation
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
            .sheet(isPresented: $showAIAnalysis) {
                AIAssistantView()
                    .environment(env)
            }
        }
    }

    private var backgroundWash: some View {
        ZStack {
            Color(.systemBackground)
            Theme.softBrandGradient
                .frame(height: 280)
                .frame(maxHeight: .infinity, alignment: .top)
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
                Spacer()
                // 頭像右上角
                NavigationLink {
                    ProfileView()
                } label: {
                    Circle().fill(Theme.brandGradient)
                        .frame(width: 42, height: 42)
                        .overlay(Text(String(env.profile.name.prefix(1)))
                            .font(.headline).foregroundStyle(.white))
                        .shadow(color: .white.opacity(0.3), radius: 8, y: 3)
                }
            }

            // 穴位標籤
            HStack(spacing: 6) {
                ForEach(p.acupoints) { a in
                    Text(a.nameZh)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(.white.opacity(0.2), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            // AR 按鈕
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

    // MARK: 健康指標

    private var healthMetricsRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("今日健康", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            let metrics = env.healthMetrics
            if metrics.isEmpty {
                HStack {
                    Text("尚未取得健康資料")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    if env.isLoading {
                        ProgressView().scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(metrics) { metric in
                        healthMetricCard(metric)
                    }
                }
            }
        }
    }

    private func healthMetricCard(_ metric: HealthMetric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: metric.kind.symbol)
                    .font(.caption)
                    .foregroundStyle(metric.kind.tint)
                Spacer()
                Text(metric.status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(metric.statusColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(metric.statusColor.opacity(0.12), in: Capsule())
            }
            Text("\(metric.value)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(metric.kind.unit)
                .font(.caption).foregroundStyle(.secondary)

            // 進度條
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 4)
                    Capsule().fill(metric.kind.tint)
                        .frame(width: geo.size.width * metric.level, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: 7 天趨勢

    private var weeklyTrend: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("7 天健康趨勢", systemImage: "chart.xyaxis.line")
                .font(.headline)

            let vitals = env.weeklyVitals()
            if vitals.count >= 2 {
                Chart {
                    ForEach(vitals, id: \.date) { v in
                        LineMark(
                            x: .value("日期", v.date, unit: .day),
                            y: .value("HRV", v.hrv)
                        )
                        .foregroundStyle(Theme.teal)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("日期", v.date, unit: .day),
                            y: .value("HRV", v.hrv)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Theme.teal.opacity(0.3), Theme.teal.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxisLabel("HRV (ms)")
                .frame(height: 160)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                // 睡眠分數趨勢
                Chart {
                    ForEach(vitals, id: \.date) { v in
                        BarMark(
                            x: .value("日期", v.date, unit: .day),
                            y: .value("睡眠", v.sleepScore)
                        )
                        .foregroundStyle(.orange.opacity(0.7))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxisLabel("睡眠分數")
                .frame(height: 120)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            } else {
                Text("資料不足，需要更多天的健康資料")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    // MARK: AI 個人化建議

    private var aiRecommendation: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("AI 個人化建議", systemImage: "sparkles")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("根據您近期的健康數據與節氣，AI 已為您調整今日處方。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let term = env.currentSolarTerm {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.haze.fill")
                            .foregroundStyle(.orange)
                        Text("今日節氣：\(term.name) · \(term.climateTag)")
                            .font(.caption)
                    }
                    Text(term.advice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showAIAnalysis = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("查看完整分析")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.teal)
                    .padding(.vertical, 12).padding(.horizontal, 16)
                    .background(Theme.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - HealthMetric display helpers

extension HealthMetric {
    var statusColor: Color {
        switch status {
        case "良好", "活躍", "充足", "穩定": .green
        case "一般", "正常", "適中": .orange
        default: .red
        }
    }
}

#Preview {
    DailyView().environment(AppEnvironment())
}
