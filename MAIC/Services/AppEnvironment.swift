import Foundation

@Observable
final class AppEnvironment {
    var health: any HealthServicing = MockHealthService()
    var data: MockDataProvider = .shared
    var profile: UserProfile = .demo
    var hasOnboarded: Bool = false
    var todaysPrescription: Prescription
    var practiceHistory: [Prescription] = []

    // MARK: - Gamification
    var streakDays: Int = 7
    var xp: Int = 1240
    var xpForNextLevel: Int = 1500
    var level: Int { max(1, xp / 500 + 1) }
    /// 7 日完成狀態（index 0 = 6 天前 … 6 = 今天）
    var weekCompletion: [Bool] = [true, true, false, true, true, true, false]
    /// 今日是否已完成處方
    var completedToday: Bool { weekCompletion.last ?? false }
    /// 今日 3 個小任務
    var dailyQuests: [DailyQuest] = [
        .init(title: "完成穴位按摩", icon: "hand.tap.fill", reward: 30, done: false),
        .init(title: "舌診打卡", icon: "mouth.fill", reward: 15, done: false),
        .init(title: "呼吸 3 分鐘", icon: "wind", reward: 10, done: true)
    ]

    init() {
        let p = MockDataProvider.shared
        self.todaysPrescription = PrescriptionEngine.generate(
            for: .demo,
            term: p.currentSolarTerm,
            vitals: p.latestVital,
            pool: p.allAcupoints
        )
    }

    func regeneratePrescription() {
        todaysPrescription = PrescriptionEngine.generate(
            for: profile,
            term: data.currentSolarTerm,
            vitals: data.latestVital,
            pool: data.allAcupoints
        )
    }

    func recordCompletion(_ p: Prescription) {
        practiceHistory.insert(p, at: 0)
        if var last = weekCompletion.last, !last {
            last = true
            weekCompletion[weekCompletion.count - 1] = true
            streakDays += 1
            xp += 30
        }
        if let i = dailyQuests.firstIndex(where: { $0.title == "完成穴位按摩" }) {
            dailyQuests[i].done = true
        }
    }
}

struct DailyQuest: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let reward: Int
    var done: Bool
}
