import Foundation

@Observable
final class AppEnvironment {
    var health: any HealthServicing = MockHealthService()
    var data: MockDataProvider = .shared
    var profile: UserProfile = .demo

    /// 今日 AI 推薦處方（結合天氣 × 健康 × 體質）
    var todaysPrescription: Prescription
    /// 最近完成的點穴紀錄
    var practiceHistory: [PointSession] = []

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

    /// 今日點穴的入口 session（每日點穴卡 → AR）
    var dailySession: PointSession { PointSession(from: todaysPrescription) }

    func recordCompletion(_ session: PointSession) {
        practiceHistory.insert(session, at: 0)
        if practiceHistory.count > 12 { practiceHistory.removeLast() }
    }
}
