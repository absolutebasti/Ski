import Foundation
import HealthKit

/// HealthKit workout session — the reason the watch may keep running in the
/// background and the source of heart rate.
///
/// `.downhillSkiing` gives the user a proper ski workout in the Fitness app and
/// gives us `workout-processing` background time for the whole ski day.
/// Requires the HealthKit capability and the `workout-processing` background
/// mode on the watch target (see docs/WATCH.md).
final class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    @Published private(set) var heartRate: Int?
    @Published private(set) var running = false

    /// Called on the main queue for every new heart-rate sample.
    var onHeartRate: ((Int) -> Void)?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(_ done: ((Bool) -> Void)? = nil) {
        guard isAvailable else { done?(false); return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        var read: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { read.insert(hr) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(energy) }
        store.requestAuthorization(toShare: share, read: read) { granted, _ in
            DispatchQueue.main.async { done?(granted) }
        }
    }

    func start() {
        guard isAvailable, session == nil else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .downhillSkiing
        config.locationType = .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            DispatchQueue.main.async { self.running = true }
        } catch {
            self.session = nil
            self.builder = nil
        }
    }

    func end() {
        guard let session, let builder else { return }
        let end = Date()
        session.end()
        builder.endCollection(withEnd: end) { _, _ in
            builder.finishWorkout { _, _ in }
        }
        self.session = nil
        self.builder = nil
        DispatchQueue.main.async {
            self.running = false
            self.heartRate = nil
        }
    }

    // MARK: HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async { self.running = toState == .running }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.running = false
            self.session = nil
            self.builder = nil
        }
    }

    // MARK: HKLiveWorkoutBuilderDelegate

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate), collectedTypes.contains(hrType) else { return }
        guard let statistics = workoutBuilder.statistics(for: hrType),
              let quantity = statistics.mostRecentQuantity() else { return }
        let bpm = Int(quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded())
        guard bpm >= 20, bpm <= 250 else { return }
        DispatchQueue.main.async {
            self.heartRate = bpm
            self.onHeartRate?(bpm)
        }
    }
}
