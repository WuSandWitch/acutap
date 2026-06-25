import Foundation

@Observable
final class MockDataProvider {
    static let shared = MockDataProvider()

    let allAcupoints: [Acupoint]
    let currentSolarTerm: SolarTerm
    let weather: Weather
    let quickIntents: [QuickIntent]
    private(set) var weeklyVitals: [VitalSnapshot]

    private init() {
        self.allAcupoints = RealAcupointData.all  // ← 真實穴位資料（79穴）
        self.currentSolarTerm = SolarTerm(
            name: "小滿",
            climateTag: "濕氣漸盛",
            advice: "宜清淡飲食、適度運動以化濕，避免久坐傷脾。可常按 足三里、三陰交 健運脾胃。"
        )
        self.weather = Weather(
            condition: .humid,
            temperature: 29,
            humidity: 78,
            city: "臺北市",
            tcmTip: "濕氣偏重，脾胃易受困。建議多按足三里、三陰交健運脾胃，少食生冷。"
        )
        self.quickIntents = MockDataProvider.seedIntents()
        self.weeklyVitals = MockDataProvider.seedVitals()
    }

    var latestVital: VitalSnapshot { weeklyVitals.last! }

    /// 依 ID 取穴位（保持 MockData 順序）
    func acupoints(ids: [String]) -> [Acupoint] {
        ids.compactMap { id in allAcupoints.first { $0.id == id } }
    }

    /// 今日健康摘要（取自最新 VitalSnapshot）
    var healthMetrics: [HealthMetric] {
        let v = latestVital
        return [
            HealthMetric(kind: .hrv, value: Int(v.hrv),
                         level: min(1, v.hrv / 70),
                         status: v.hrv >= 50 ? "良好" : "偏低"),
            HealthMetric(kind: .sleep, value: v.sleepScore,
                         level: Double(v.sleepScore) / 100,
                         status: v.sleepScore >= 75 ? "充足" : "不足"),
            HealthMetric(kind: .restingHR, value: v.restingHR,
                         level: 1 - min(1, Double(v.restingHR - 50) / 40),
                         status: v.restingHR <= 65 ? "穩定" : "偏快"),
            HealthMetric(kind: .steps, value: v.steps,
                         level: min(1, Double(v.steps) / 10000),
                         status: v.steps >= 8000 ? "達標" : "再加油")
        ]
    }

    private static func seedIntents() -> [QuickIntent] {
        [
            // 情緒
            .init(category: .emotion, label: "焦慮緊張", symbol: "wind",
                  prompt: "我最近感到焦慮緊張，可以點什麼穴位放鬆？",
                  acupointIDs: ["HT7", "PC6", "LV3"]),
            .init(category: .emotion, label: "心情低落", symbol: "cloud.rain",
                  prompt: "我心情有點低落鬱悶，有什麼穴位能幫忙？",
                  acupointIDs: ["CV17", "LV3", "PC6"]),
            .init(category: .emotion, label: "壓力大", symbol: "bolt.heart",
                  prompt: "工作壓力好大，想舒壓放鬆。",
                  acupointIDs: ["GB20", "GB21", "HT7"]),
            // 生理
            .init(category: .physical, label: "頭痛", symbol: "brain.head.profile",
                  prompt: "我現在頭痛，可以點什麼穴位？",
                  acupointIDs: ["GV20", "GB20", "LI4"]),
            .init(category: .physical, label: "肩頸僵硬", symbol: "figure.stand",
                  prompt: "肩頸很僵硬痠痛，該按哪裡？",
                  acupointIDs: ["GB21", "GB20", "LI4"]),
            .init(category: .physical, label: "失眠", symbol: "moon.zzz",
                  prompt: "我最近睡不好、難入睡，有助眠的穴位嗎？",
                  acupointIDs: ["HT7", "SP6", "PC6"]),
            .init(category: .physical, label: "胸悶", symbol: "lungs",
                  prompt: "覺得胸悶氣短，可以按什麼穴位？",
                  acupointIDs: ["CV17", "PC6", "LU7"]),
            .init(category: .physical, label: "疲倦", symbol: "battery.25",
                  prompt: "整天很疲倦提不起勁，怎麼按提神？",
                  acupointIDs: ["ST36", "GV20", "BL23"]),
            // 目標
            .init(category: .goal, label: "提升專注", symbol: "scope",
                  prompt: "想提升專注力與精神，該點哪些穴位？",
                  acupointIDs: ["GV20", "GB20", "PC6"]),
            .init(category: .goal, label: "助消化", symbol: "fork.knife",
                  prompt: "想幫助腸胃消化，有推薦的穴位嗎？",
                  acupointIDs: ["ST36", "SP6"]),
            .init(category: .goal, label: "增強免疫", symbol: "shield.lefthalf.filled",
                  prompt: "想日常保健、增強免疫力。",
                  acupointIDs: ["ST36", "LI4", "BL23"])
        ]
    }

    private static func seedVitals() -> [VitalSnapshot] {
        let cal = Calendar.current
        var rng = SeededRandom(seed: 20260531)
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return VitalSnapshot(
                date: date,
                hrv: Double(38 + rng.next(0...22)),
                sleepScore: 62 + rng.next(0...28),
                spo2: 96 + Double(rng.next(0...3)),
                restingHR: 58 + rng.next(0...8),
                steps: 4200 + rng.next(0...6400),
                mindfulMinutes: rng.next(0...18)
            )
        }
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next(_ range: ClosedRange<Int>) -> Int {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(state % span)
    }
}
