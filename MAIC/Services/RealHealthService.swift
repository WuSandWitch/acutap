import Foundation
import HealthKit

final class RealHealthService: HealthServicing {
    private let healthStore = HKHealthStore()
    private let provider = MockDataProvider.shared  // fallback
    
    // 請求授權
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
        ]
        
        return try await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    print("HealthKit auth error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    // MARK: - HealthServicing
    
    func latestSnapshot() -> VitalSnapshot {
        // 非同步從 HealthKit 抓最新資料
        // 這邊用 Task 包裝同步回傳，非同步版本由 callers 自行處理
        // 這裡先回傳 Mock 當 fallback（真正的 async fetching 在 syncAllToBackend）
        return provider.latestVital
    }
    
    func weekly() -> [VitalSnapshot] {
        return provider.weeklyVitals
    }
    
    // 完整同步（從 HealthKit 讀取 + 回傳結構化資料）
    func fetchAndAnalyze() async -> (latest: VitalSnapshot, weekly: [VitalSnapshot], metrics: [HealthMetric]) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return (provider.latestVital, provider.weeklyVitals, provider.healthMetrics)
        }
        
        async let hrv = fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .second(), multiplier: 1000)
        async let restingHR = fetchLatestQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        async let steps = fetchSumQuantity(.stepCount, unit: .count())
        async let spo2 = fetchLatestQuantity(.oxygenSaturation, unit: .percent())
        async let sleep = fetchSleepScore()
        async let mindful = fetchMindfulMinutes()
        
        let (hrvVal, hrVal, stepsVal, spo2Val, sleepVal, mindfulVal) = await (hrv, restingHR, steps, spo2, sleep, mindful)
        
        let today = Date()
        let snapshot = VitalSnapshot(
            date: today,
            hrv: hrvVal,
            sleepScore: sleepVal,
            spo2: spo2Val,
            restingHR: Int(hrVal),
            steps: Int(stepsVal),
            mindfulMinutes: Int(mindfulVal)
        )
        
        // 建立 weekly 列表（最近 7 天）
        var weeklySnapshots: [VitalSnapshot] = []
        for dayOffset in (0..<7).reversed() {
            let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today)!
            if dayOffset == 0 {
                weeklySnapshots.append(snapshot)
            } else {
                let dayHrv = try? await fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .second(), multiplier: 1000, for: day)
                let dayHr = try? await fetchLatestQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()), for: day)
                let daySteps = try? await fetchSumQuantity(.stepCount, unit: .count(), for: day)
                let daySleep = try? await fetchSleepScore(for: day)
                weeklySnapshots.append(VitalSnapshot(
                    date: day,
                    hrv: dayHrv ?? 0,
                    sleepScore: daySleep ?? 0,
                    spo2: 0.98,
                    restingHR: Int(dayHr ?? 0),
                    steps: Int(daySteps ?? 0),
                    mindfulMinutes: 0
                ))
            }
        }
        
        // 計算 HealthMetrics
        let metrics = computeMetrics(from: snapshot)
        
        return (snapshot, weeklySnapshots, metrics)
    }
    
    // 將 HealthKit 資料同步到後端
    func syncToBackend(snapshots: [VitalSnapshot]) async throws -> HealthSyncResponse? {
        let request = HealthSyncRequest(snapshots: snapshots)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        
        return try await APIService.shared.post(APIConfig.Endpoint.healthSync, jsonData: data)
    }
    
    // MARK: - Private Helpers
    
    private func fetchLatestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, multiplier: Double = 1, for date: Date = Date()) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: date.addingTimeInterval(86400))
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit) * multiplier)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSumQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, for date: Date = Date()) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: date.addingTimeInterval(86400))
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let val = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: val)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepScore(for date: Date = Date()) async -> Int {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay.addingTimeInterval(-86400), end: startOfDay.addingTimeInterval(86400))
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 0, sortDescriptors: []) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                // 計算總睡眠時間（分鐘）
                let totalSeconds = samples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let minutes = Int(totalSeconds / 60)
                // 轉換成分數（假設 8 小時 = 480 分鐘為滿分）
                let score = min(100, Int(Double(minutes) / 480.0 * 100))
                continuation.resume(returning: score)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchMindfulMinutes(for date: Date = Date()) async -> Int {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: date.addingTimeInterval(86400))
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 0, sortDescriptors: []) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                let total = samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: Int(total / 60))
            }
            healthStore.execute(query)
        }
    }
    
    private func computeMetrics(from snapshot: VitalSnapshot) -> [HealthMetric] {
        // 與 MockDataProvider 相同的計算邏輯
        let hrvLevel = min(1, max(0, snapshot.hrv / 80))
        let sleepLevel = min(1, max(0, Double(snapshot.sleepScore) / 100))
        let hrLevel = 1 - min(1, max(0, (Double(snapshot.restingHR) - 40) / 40))
        let stepsLevel = min(1, max(0, Double(snapshot.steps) / 10000))
        
        return [
            HealthMetric(kind: .hrv, value: Int(snapshot.hrv), level: hrvLevel, status: hrvLevel > 0.6 ? "良好" : hrvLevel > 0.3 ? "一般" : "偏低"),
            HealthMetric(kind: .sleep, value: snapshot.sleepScore, level: sleepLevel, status: snapshot.sleepScore > 75 ? "良好" : snapshot.sleepScore > 50 ? "一般" : "不足"),
            HealthMetric(kind: .restingHR, value: snapshot.restingHR, level: hrLevel, status: hrLevel > 0.6 ? "良好" : hrLevel > 0.3 ? "正常" : "偏高"),
            HealthMetric(kind: .steps, value: snapshot.steps, level: stepsLevel, status: snapshot.steps > 8000 ? "活躍" : snapshot.steps > 5000 ? "適中" : "偏低")
        ]
    }
}

// Health sync response types
struct HealthSyncResponse: Codable {
    let assessments: [HealthAssessment]
    let overallStatus: String
    let tcmAssessment: String
    let recommendations: [String]
    let trend: TrendInfo
}

struct HealthAssessment: Codable {
    let name: String
    let value: Double
    let unit: String
    let status: String
    let tcmAdvice: String
}

struct TrendInfo: Codable {
    let direction: String
    let details: String
}

struct HealthSyncRequest: Codable {
    let snapshots: [VitalSnapshot]
}
