import Foundation

protocol HealthServicing {
    func latestSnapshot() -> VitalSnapshot
    func weekly() -> [VitalSnapshot]
}

struct MockHealthService: HealthServicing {
    private let provider = MockDataProvider.shared
    func latestSnapshot() -> VitalSnapshot { provider.latestVital }
    func weekly() -> [VitalSnapshot] { provider.weeklyVitals }
}
