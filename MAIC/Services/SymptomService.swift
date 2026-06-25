import Foundation

struct SymptomRequest: Codable {
    let symptoms: [String]
    let constitution: String?
    let hrv: Double?
    let sleepScore: Int?
    let restingHR: Int?
    let steps: Int?
}

struct SymptomResponse: Codable {
    let analysis: String
    let pattern: SymptomPattern
    let acupoints: [SymptomAcupoint]
    let lifestyleTips: [String]
}

struct SymptomPattern: Codable {
    let name: String
    let description: String
}

struct SymptomAcupoint: Codable, Identifiable {
    let id: String
    let nameZh: String
    let meridian: String
    let relevance: Double
    let location: String?
    let pressSeconds: Int?
    let fullData: Acupoint?  // 完整穴位資料（可選）
}

final class SymptomService {
    static let shared = SymptomService()
    private let api = APIService.shared
    
    func analyze(symptoms: [String], constitution: String? = nil,
                 hrv: Double? = nil, sleepScore: Int? = nil,
                 restingHR: Int? = nil, steps: Int? = nil) async throws -> SymptomResponse {
        let request = SymptomRequest(
            symptoms: symptoms, constitution: constitution,
            hrv: hrv, sleepScore: sleepScore,
            restingHR: restingHR, steps: steps
        )
        return try await api.post(.symptomAnalyze, body: request)
    }
}
