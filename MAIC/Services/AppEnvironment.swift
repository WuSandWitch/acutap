import Foundation
import Observation

@Observable
final class AppEnvironment {
    // MARK: - Services
    var health: HealthServicing = RealHealthService()
    let api = APIService.shared
    let data = MockDataProvider.shared

    // MARK: - State
    var profile: UserProfile = UserProfile(
        name: AuthService.shared.userName ?? AuthService.shared.userEmail ?? "使用者",
        birthYear: Calendar.current.component(.year, from: Date()) - 25,
        constitution: [.balanced: 1.0]
    )
    var todaysPrescription: Prescription
    var practiceHistory: [PointSession] = []

    // MARK: - Real Data (loaded from backend)
    var currentWeather: Weather?
    var currentSolarTerm: SolarTerm?
    var healthMetrics: [HealthMetric] = []
    var isLoading = false
    var healthKitAuthorized = false
    var backendAvailable = false
    var lastSyncDate: Date?

    init() {
        let p = MockDataProvider.shared
        self.todaysPrescription = PrescriptionEngine.generate(
            for: .demo,
            term: p.currentSolarTerm,
            vitals: p.latestVital,
            pool: p.allAcupoints
        )
    }

    /// 在 App 啟動時呼叫：初始化 HealthKit + 從後端載入資料
    @MainActor
    func initialize() async {
        isLoading = true

        // 1. HealthKit 授權
        if let realHealth = health as? RealHealthService {
            do {
                healthKitAuthorized = try await realHealth.requestAuthorization()
                print("[AppEnv] HealthKit authorized: \(healthKitAuthorized)")
            } catch {
                print("[AppEnv] HealthKit error: \(error)")
                healthKitAuthorized = false
            }
        }

        // 2. 從後端載入天氣 + 節氣
        await fetchWeatherAndSolarTerm()

        // 3. 同步 HealthKit 資料到後端（如有授權）
        if healthKitAuthorized {
            await syncHealthToBackend()
        }

        // 4. 重新產生今日處方（若有真實資料）
        regeneratePrescription()
        isLoading = false
    }

    /// 從後端載入天氣與節氣
    @MainActor
    func fetchWeatherAndSolarTerm() async {
        // 並行載入
        async let weatherTask: () = fetchWeather()
        async let solarTask: () = fetchSolarTerm()
        _ = await (weatherTask, solarTask)
    }

    @MainActor
    func fetchWeather() async {
        do {
            let raw: GeocodedWeather = try await api.get(.weather(city: "Taipei"))
            self.currentWeather = Weather(
                condition: Weather.Condition(rawValue: raw.condition) ?? .cloudy,
                temperature: raw.temperature,
                humidity: raw.humidity,
                city: raw.city,
                tcmTip: raw.tcmTip
            )
            backendAvailable = true
        } catch {
            print("[AppEnv] Weather fetch failed: \(error)")
            self.currentWeather = data.weather
        }
    }

    @MainActor
    func fetchSolarTerm() async {
        do {
            let raw: SolarTermResponse = try await api.get(.solarTerm)
            self.currentSolarTerm = SolarTerm(
                name: raw.name,
                climateTag: raw.climateTag ?? raw.name + "養生",
                advice: raw.advice ?? ""
            )
        } catch {
            print("[AppEnv] Solar term fetch failed: \(error)")
            self.currentSolarTerm = data.currentSolarTerm
        }
    }

    /// 從 HealthKit 讀取資料並同步到後端
    func syncHealthToBackend() async {
        guard let realHealth = health as? RealHealthService else { return }

        let (latest, weekly, metrics) = await realHealth.fetchAndAnalyze()
        self.healthMetrics = metrics

        // 同步到後端
        do {
            let response = try await realHealth.syncToBackend(snapshots: weekly)
            print("[AppEnv] Health sync response: \(response?.overallStatus ?? "none")")
            lastSyncDate = Date()
        } catch {
            print("[AppEnv] Health sync failed: \(error)")
        }
    }

    /// 重新產生處方（使用真實資料或 Mock fallback）
    func regeneratePrescription() {
        let term = currentSolarTerm ?? data.currentSolarTerm
        let vitals = latestVital()
        todaysPrescription = PrescriptionEngine.generate(
            for: profile,
            term: term,
            vitals: vitals,
            pool: data.allAcupoints
        )
    }

    /// 取得最新的健康快照（真實或 Mock）
    func latestVital() -> VitalSnapshot {
        if healthKitAuthorized, let realHealth = health as? RealHealthService {
            return realHealth.latestSnapshot()
        }
        return data.latestVital
    }

    /// 取得本週健康資料（真實或 Mock）
    func weeklyVitals() -> [VitalSnapshot] {
        if healthKitAuthorized, let realHealth = health as? RealHealthService {
            return realHealth.weekly()
        }
        return data.weeklyVitals
    }

    // MARK: - 點穴 Session

    var dailySession: PointSession {
        PointSession(from: todaysPrescription)
    }

    func recordCompletion(_ session: PointSession) {
        practiceHistory.insert(session, at: 0)
        if practiceHistory.count > 12 { practiceHistory.removeLast() }
    }

    // MARK: - 🎴 看看狀態吧

    func fetchHealthInsights() async -> HealthInsights? {
        let vital = latestVital()
        let dominant = profile.dominantConstitution
        let term = currentSolarTerm

        let body: [String: Any] = [
            "hrv": vital.hrv as Any,
            "sleepScore": vital.sleepScore as Any,
            "restingHR": vital.restingHR as Any,
            "steps": vital.steps as Any,
            "constitution": dominant.displayName,
            "constitutionScore": profile.constitution[dominant] ?? 0,
            "solarTerm": term?.name ?? "",
            "solarTermAdvice": term?.advice ?? "",
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            return try await api.post(.healthInsights, jsonData: data)
        } catch {
            print("[AppEnv] Health insights failed: \(error)")
            return nil
        }
    }
}

// MARK: - Backend Response Models (蛇形→駝峰)

struct GeocodedWeather: Codable {
    let condition: String
    let temperature: Int
    let humidity: Int
    let city: String
    let tcmTip: String
}

struct SolarTermResponse: Codable {
    let name: String
    let climateTag: String?
    let advice: String?
}
