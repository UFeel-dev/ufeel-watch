import Foundation
import HealthKit
import Observation
import WatchConnectivity

/// Runs a workout, the only way to read the heart rate continuously, and sends each reading to
/// the iPhone app, which forwards it to UFeel. The workout is discarded when it stops.
@MainActor
@Observable
final class HeartRateWorkout: NSObject {
    private(set) var isRunning = false
    private(set) var bpm: Int?
    private(set) var phoneReachable = false
    private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func start() async {
        guard !isRunning else {
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Health data is not available on this watch."
            return
        }
        errorMessage = nil

        do {
            try await healthStore.requestAuthorization(
                toShare: [HKQuantityType.workoutType()],
                read: [HKQuantityType(.heartRate)]
            )

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .other
            configuration.locationType = .indoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
            isRunning = true
        } catch {
            errorMessage = error.localizedDescription
            await stop()
        }
    }

    func stop() async {
        let session = self.session
        let builder = self.builder
        self.session = nil
        self.builder = nil
        isRunning = false
        bpm = nil

        session?.end()
        if let builder {
            try? await builder.endCollection(at: Date())
            builder.discardWorkout()
        }
    }

    private func send(bpm: Int) {
        self.bpm = bpm
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            return
        }
        session.sendMessage(HeartRateMessage.message(bpm: bpm), replyHandler: nil) { error in
            let message = error.localizedDescription
            Task { @MainActor in
                self.errorMessage = message
            }
        }
    }

    private func fail(_ message: String) async {
        errorMessage = message
        await stop()
    }
}

extension HeartRateWorkout: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let heartRate = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRate),
              let quantity = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity()
        else {
            return
        }
        let bpm = Int(quantity.doubleValue(for: .count().unitDivided(by: .minute())).rounded())
        guard HeartRateMessage.validRange.contains(bpm) else {
            return
        }
        Task { @MainActor in
            self.send(bpm: bpm)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension HeartRateWorkout: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            await self.fail(message)
        }
    }
}

extension HeartRateWorkout: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.phoneReachable = reachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.phoneReachable = reachable
        }
    }
}
