import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var page = 0
    @State private var answers: [Int] = [-1, -1, -1]

    private let questions: [(q: String, opts: [String])] = [
        ("最近一個月，你最常出現的不適？",
         ["容易疲倦、氣短", "胸悶、情緒鬱悶", "口乾舌燥、失眠", "手足冰冷、怕冷"]),
        ("你的睡眠狀態通常是？",
         ["入睡快、深沉", "難入睡或多夢", "淺眠易醒", "醒後仍感疲倦"]),
        ("一天的精神狀態？",
         ["充沛穩定", "下午易倦", "整日昏沉", "情緒起伏大"])
    ]

    private var totalPages: Int { 2 + questions.count }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                introPage.tag(0)
                permissionPage.tag(1)
                ForEach(questions.indices, id: \.self) { i in
                    quizPage(index: i).tag(2 + i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomBar
        }
        .background(Theme.softBrandGradient.ignoresSafeArea())
    }

    private var introPage: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.brandGradient)
            Text("Tap Tap!")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
            Text("把中醫養生，化作每日 90 秒的儀式")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
        }
    }

    private var permissionPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("我們會用到")
                .font(.largeTitle.weight(.semibold))
                .padding(.top, Theme.Spacing.xl)
            permissionRow(icon: "heart.text.square",
                          title: "健康資料",
                          subtitle: "讀取 HRV、睡眠與血氧，作為每日處方依據。")
            permissionRow(icon: "camera",
                          title: "相機",
                          subtitle: "用於舌診與面診的本地端體質辨識。")
            permissionRow(icon: "bell.badge",
                          title: "通知",
                          subtitle: "在合適的時段提醒您完成今日按摩。")
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    private func permissionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func quizPage(index: Int) -> some View {
        let q = questions[index]
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("體質快測 \(index + 1) / \(questions.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.xl)
            Text(q.q).font(.title.weight(.semibold))
            VStack(spacing: Theme.Spacing.s) {
                ForEach(q.opts.indices, id: \.self) { i in
                    Button {
                        answers[index] = i
                    } label: {
                        HStack {
                            Text(q.opts[i]).multilineTextAlignment(.leading)
                            Spacer()
                            if answers[index] == i {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(answers[index] == i
                                      ? Color.accentColor.opacity(0.14)
                                      : Color(.secondarySystemBackground))
                        )
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    private var bottomBar: some View {
        HStack {
            if page > 0 {
                Button("上一步") { withAnimation { page -= 1 } }
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: next) {
                Text(page == totalPages - 1 ? "完成" : "繼續")
                    .font(.headline)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .disabled(isContinueDisabled)
            .opacity(isContinueDisabled ? 0.5 : 1)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.l)
    }

    private var isContinueDisabled: Bool {
        page >= 2 && answers[page - 2] < 0
    }

    private func next() {
        if page == totalPages - 1 { finish() }
        else { withAnimation { page += 1 } }
    }

    private func finish() {
        let map: [Constitution] = [.qiDeficiency, .qiStagnation, .yinDeficiency, .yangDeficiency]
        var counts: [Constitution: Double] = [:]
        for a in answers where a >= 0 { counts[map[a], default: 0] += 1 }
        let total = max(1.0, counts.values.reduce(0, +))
        let normalized = counts.mapValues { $0 / total }
        env.profile.constitution = normalized.isEmpty ? [.balanced: 1] : normalized
        env.regeneratePrescription()
        withAnimation { env.hasOnboarded = true }
    }
}
