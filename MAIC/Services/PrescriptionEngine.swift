import Foundation

enum PrescriptionEngine {
    static func generate(for profile: UserProfile,
                         term: SolarTerm,
                         vitals: VitalSnapshot,
                         pool: [Acupoint]) -> Prescription {
        let dominant = profile.dominantConstitution
        let byId: (String) -> Acupoint? = { id in pool.first { $0.id == id } }

        let ids: [String]
        switch dominant {
        case .qiStagnation:
            ids = ["LV3", "PC6", "CV17", "GB21"]
        case .qiDeficiency:
            ids = ["ST36", "SP6", "BL23", "GV20"]
        case .yinDeficiency:
            ids = ["SP6", "HT7", "PC6", "LV3"]
        case .dampHeat, .phlegmDamp:
            ids = ["ST36", "SP6", "LI4", "GB20"]
        case .yangDeficiency:
            ids = ["BL23", "ST36", "GV20", "SP6"]
        case .bloodStasis:
            ids = ["SP6", "LV3", "LI4", "GB21"]
        default:
            ids = ["LI4", "ST36", "PC6", "GB20"]
        }

        var picks = ids.compactMap(byId)
        if vitals.sleepScore < 75, let shenmen = byId("HT7"), !picks.contains(shenmen) {
            if !picks.isEmpty { picks[picks.count - 1] = shenmen }
        }

        let title = "\(dominant.displayName) × \(term.climateTag)"
        let rationale = "結合今日 \(term.name) 節氣與您的\(dominant.displayName)，本套處方著重於疏通經絡、調和氣血。"
        return Prescription(
            id: UUID(),
            date: Date(),
            title: title,
            rationale: rationale,
            acupoints: picks
        )
    }
}
