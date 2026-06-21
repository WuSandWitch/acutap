import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showPractice = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    topBar
                    prescriptionCard
                    weekStreakSection
                    questsSection
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showPractice) {
                PracticeView(prescription: env.todaysPrescription)
            }
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting + ", " + env.profile.name)
                    .font(.title2.weight(.semibold))
                Text(Date.now, format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PillTag(text: env.data.currentSolarTerm.name, systemImage: "leaf.fill")
            NavigationLink {
                ProfileView()
            } label: {
                Circle()
                    .fill(Theme.brandGradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(env.profile.name.prefix(1)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    )
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

    // MARK: - Prescription info card
    private var prescriptionCard: some View {
        let p = env.todaysPrescription
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("今日調養處方")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(p.totalSeconds)s")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
            }
            Text(p.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text(p.rationale)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(p.acupoints) { a in
                    Text(a.nameZh)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.18), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            Button {
                showPractice = true
            } label: {
                HStack {
                    Image(systemName: env.completedToday ? "checkmark.circle.fill" : "play.fill")
                    Text(env.completedToday ? "再做一次" : "開始 \(p.totalSeconds) 秒按摩")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white, in: Capsule())
                .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.l)
        .background(Theme.brandGradient,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.25), radius: 16, y: 8)
    }

    // MARK: - Daily quests
    private var questsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("每日任務").font(.headline)
                Spacer()
                Text("\(env.dailyQuests.filter(\.done).count) / \(env.dailyQuests.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            VStack(spacing: 10) {
                ForEach(env.dailyQuests) { q in questRow(q) }
            }
        }
    }

    private func questRow(_ q: DailyQuest) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle().fill(q.done
                              ? AnyShapeStyle(Theme.brandGradient)
                              : AnyShapeStyle(Color.accentColor.opacity(0.14)))
                Image(systemName: q.done ? "checkmark" : q.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(q.done ? .white : Color.accentColor)
            }
            .frame(width: 40, height: 40)

            Text(q.title)
                .font(.subheadline.weight(.medium))
                .strikethrough(q.done, color: .secondary)
                .foregroundStyle(q.done ? .secondary : .primary)
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill").font(.caption2)
                Text("+\(q.reward)").font(.caption.weight(.bold).monospacedDigit())
            }
            .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.10))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(red: 0.95, green: 0.75, blue: 0.18).opacity(0.18),
                        in: Capsule())
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(q.done ? 0.72 : 1)
    }

    // MARK: - Week streak
    private var weekStreakSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("本週連續").font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.20))
                    Text("\(env.streakDays) 天")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
            HStack(spacing: 8) {
                ForEach(Array(env.weekCompletion.enumerated()), id: \.offset) { i, done in
                    weekDot(label: weekdayLabel(daysAgo: 6 - i),
                            done: done,
                            isToday: i == env.weekCompletion.count - 1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private func weekDot(label: String, done: Bool, isToday: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(done
                          ? AnyShapeStyle(Theme.brandGradient)
                          : AnyShapeStyle(Color.secondary.opacity(0.18)))
                    .frame(width: 32, height: 32)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                if isToday {
                    Circle().stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 40, height: 40)
                }
            }
            .frame(width: 40, height: 40)
            Text(label)
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.accentColor : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_TW")
        fmt.dateFormat = "EEEEE"
        return fmt.string(from: date)
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}
