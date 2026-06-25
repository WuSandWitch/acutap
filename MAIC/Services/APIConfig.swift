import Foundation

enum APIConfig {
    // 開發階段先用 localhost，上線後改為正式 domain
    static var baseURL: String {
        // 從 Info.plist 或環境變數讀取
        ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8000"
    }
    
    static let apiPrefix = "/api"
    
    enum Endpoint {
        case symptomAnalyze
        case healthSync
        case chat
        case weather(city: String)
        case solarTerm
        case solarTermByDate(year: Int, month: Int, day: Int)
        case solarTermAll
        case acupoints
        case acupoint(id: String)
        case meridians
        case prescription
        
        var path: String {
            switch self {
            case .symptomAnalyze: return "/api/symptom-analyze"
            case .healthSync: return "/api/health/sync"
            case .chat: return "/api/chat"
            case .weather(let city): return "/api/weather?city=\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city)"
            case .solarTerm: return "/api/solar-term"
            case .solarTermByDate(let y, let m, let d): return "/api/solar-term/by-date?year=\(y)&month=\(m)&day=\(d)"
            case .solarTermAll: return "/api/solar-term/all"
            case .acupoints: return "/api/acupoints"
            case .acupoint(let id): return "/api/acupoints/\(id)"
            case .meridians: return "/api/meridians"
            case .prescription: return "/api/prescription"
            }
        }
        
        var url: URL {
            URL(string: APIConfig.baseURL + path)!
        }
    }
}
