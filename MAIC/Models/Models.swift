import SwiftUI

enum Constitution: String, Codable, CaseIterable, Identifiable, Hashable {
    case balanced, qiDeficiency, yinDeficiency, yangDeficiency,
         dampHeat, phlegmDamp, bloodStasis, qiStagnation, specialDiathesis

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balanced: "平和質"
        case .qiDeficiency: "氣虛質"
        case .yinDeficiency: "陰虛質"
        case .yangDeficiency: "陽虛質"
        case .dampHeat: "濕熱質"
        case .phlegmDamp: "痰濕質"
        case .bloodStasis: "血瘀質"
        case .qiStagnation: "氣鬱質"
        case .specialDiathesis: "特稟質"
        }
    }

    var summary: String {
        switch self {
        case .balanced: "陰陽氣血調和，體態適中、精力充沛。"
        case .qiDeficiency: "元氣不足，易疲倦、聲音低弱、易出汗。"
        case .yinDeficiency: "體內津液不足，常口乾、手足心熱、失眠。"
        case .yangDeficiency: "陽氣虛衰，怕冷、手足不溫、精神不振。"
        case .dampHeat: "體內濕熱蘊結，面油、口苦、易長痘。"
        case .phlegmDamp: "體型偏胖、易倦、痰多、舌苔厚膩。"
        case .bloodStasis: "血行不暢，膚色晦暗、易瘀青、經痛。"
        case .qiStagnation: "情志不暢，易鬱悶、胸悶、嘆息。"
        case .specialDiathesis: "先天稟賦特殊，易過敏。"
        }
    }
}

struct SolarTerm: Codable, Hashable {
    let name: String
    let climateTag: String
    let advice: String
}

struct BodyPoint: Codable, Hashable {
    enum Side: String, Codable, Hashable { case front, back }
    let side: Side
    let x: Double   // 0...1 normalized
    let y: Double
}

struct Acupoint: Identifiable, Codable, Hashable {
    let id: String
    let nameZh: String
    let pinyin: String
    let meridian: String
    let location: String
    let indications: [String]
    let pressSeconds: Int
    let bodyPoint: BodyPoint
}

struct Prescription: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let title: String
    let rationale: String
    let acupoints: [Acupoint]
    var totalSeconds: Int { acupoints.reduce(0) { $0 + $1.pressSeconds } }
}

struct VitalSnapshot: Codable, Hashable {
    let date: Date
    let hrv: Double
    let sleepScore: Int
    let spo2: Double
    let restingHR: Int
    var steps: Int = 0
    var mindfulMinutes: Int = 0
}

// MARK: - 天氣（每日點穴的環境依據）

struct Weather: Codable, Hashable {
    enum Condition: String, Codable {
        case sunny, cloudy, rainy, humid, windy, cold

        var symbol: String {
            switch self {
            case .sunny:  "sun.max.fill"
            case .cloudy: "cloud.fill"
            case .rainy:  "cloud.rain.fill"
            case .humid:  "humidity.fill"
            case .windy:  "wind"
            case .cold:   "thermometer.snowflake"
            }
        }

        var displayName: String {
            switch self {
            case .sunny:  "晴朗"
            case .cloudy: "多雲"
            case .rainy:  "降雨"
            case .humid:  "濕悶"
            case .windy:  "風大"
            case .cold:   "偏冷"
            }
        }
    }

    let condition: Condition
    let temperature: Int      // °C
    let humidity: Int         // %
    let city: String
    /// 中醫養生觀點的天氣提示
    let tcmTip: String
}

// MARK: - 健康指標（HealthKit 摘要卡）

struct HealthMetric: Identifiable, Hashable {
    enum Kind: String, CaseIterable {
        case hrv, sleep, restingHR, steps

        var title: String {
            switch self {
            case .hrv: "心率變異"
            case .sleep: "睡眠分數"
            case .restingHR: "靜息心率"
            case .steps: "步數"
            }
        }
        var unit: String {
            switch self {
            case .hrv: "ms"
            case .sleep: "分"
            case .restingHR: "bpm"
            case .steps: "步"
            }
        }
        var symbol: String {
            switch self {
            case .hrv: "waveform.path.ecg"
            case .sleep: "bed.double.fill"
            case .restingHR: "heart.fill"
            case .steps: "figure.walk"
            }
        }
        var tint: Color {
            switch self {
            case .hrv: Theme.teal
            case .sleep: Color(red: 0.45, green: 0.40, blue: 0.85)
            case .restingHR: Color(red: 0.92, green: 0.35, blue: 0.42)
            case .steps: Color(red: 0.30, green: 0.72, blue: 0.55)
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let value: Int
    /// 0...1，相對於健康基準的水位，用於環狀進度
    let level: Double
    /// 簡短狀態（如「良好」「偏低」）
    let status: String
}

// MARK: - 統一的「點穴 session」—— 所有點穴入口都導向 AR

struct PointSession: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let acupoints: [Acupoint]

    var totalSeconds: Int { acupoints.reduce(0) { $0 + $1.pressSeconds } }

    init(title: String, subtitle: String = "", acupoints: [Acupoint]) {
        self.title = title
        self.subtitle = subtitle
        self.acupoints = acupoints
    }

    init(from p: Prescription) {
        self.title = p.title
        self.subtitle = p.rationale
        self.acupoints = p.acupoints
    }
}

// MARK: - AI 快捷意圖（情緒 / 生理 / 目標）

struct QuickIntent: Identifiable, Hashable {
    enum Category: String, CaseIterable, Identifiable {
        case emotion, physical, goal
        var id: String { rawValue }
        var title: String {
            switch self {
            case .emotion: "情緒狀態"
            case .physical: "生理狀態"
            case .goal: "我的目標"
            }
        }
        var symbol: String {
            switch self {
            case .emotion: "face.smiling"
            case .physical: "figure.mind.and.body"
            case .goal: "target"
            }
        }
    }

    let id = UUID()
    let category: Category
    let label: String
    let symbol: String
    /// 點選後送給 AI 的句子
    let prompt: String
    /// 對應推薦穴位 ID
    let acupointIDs: [String]
}

struct UserProfile: Codable {
    var name: String
    var birthYear: Int
    var constitution: [Constitution: Double]

    static let demo = UserProfile(
        name: "Luis",
        birthYear: 1998,
        constitution: [.qiStagnation: 0.42, .qiDeficiency: 0.31, .balanced: 0.27]
    )

    var dominantConstitution: Constitution {
        constitution.max(by: { $0.value < $1.value })?.key ?? .balanced
    }
}
