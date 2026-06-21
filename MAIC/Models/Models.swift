import Foundation

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
