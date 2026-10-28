import Foundation
import HealthKit
import Observation
import WatchKit

/// Runs the watch's HealthKit workout session: live heart rate and calories, and
/// the workout that's saved to Apple Health (which is what fills the Exercise ring).
@Observable
final class WorkoutManager: NSObject {
    static let shared = WorkoutManager()

    private(set) var isRunning = false
    private(set) var isPaused = false
    private(set) var heartRate: Double = 0
    private(set) var activeEnergy: Double = 0
    /// The latest workout state sent by the iPhone.
    private(set) var phoneState: PhoneWorkoutState?

    @ObservationIgnored private let healthStore = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var endAction: EndAction?
    /// The iPhone workout this session is recording, if any.
    @ObservationIgnored private var linkedWorkoutID: UUID?
    @ObservationIgnored private var lastHeartRateSent = Date.distantPast
    @ObservationIgnored private var restTask: Task<Void, Never>?

    private enum EndAction {
        case save(name: String, endDate: Date)
        case discard
    }

    /// Time recorded so far, excluding pauses.
    func elapsedTime(at date: Date) -> TimeInterval {
        builder?.elapsedTime(at: date) ?? 0
    }

    // MARK: - Controls

    func start() {
        guard session == nil else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        Task { @MainActor in
            do {
                try await healthStore.requestAuthorization(
                    toShare: [HKObjectType.workoutType()],
                    read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
                )
                let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                session.delegate = self
                builder.delegate = self
                self.session = session
                self.builder = builder
                self.endAction = nil
                self.heartRate = 0
                self.activeEnergy = 0

                let startDate = Date()
                session.startActivity(with: startDate)
                try await builder.beginCollection(at: startDate)
                self.isRunning = true
                self.isPaused = false

                if let phoneState, phoneState.phase == .active {
                    link(to: phoneState.id)
                }
            } catch {
                print("Couldn't start workout: \(error)")
                reset()
            }
        }
    }

    func togglePause() {
        guard let session else { return }
        isPaused ? session.resume() : session.pause()
    }

    /// End from the watch. Saves to Apple Health under the iPhone workout's name if there is one.
    func end() {
        let name = phoneState.flatMap { $0.phase == .active ? $0.name : nil } ?? "Strength Training"
        endAction = .save(name: name, endDate: .now)
        session?.end()
    }

    // MARK: - From the iPhone

    func apply(_ state: PhoneWorkoutState) {
        phoneState = state

        switch state.phase {
        case .active:
            if isRunning, linkedWorkoutID == nil { link(to: state.id) }
            scheduleRestHaptic(at: state.restEndDate)
        case .finished, .discarded:
            restTask?.cancel()
            guard session != nil, linkedWorkoutID == nil || linkedWorkoutID == state.id else { return }
            endAction = (state.phase == .finished && state.saveToHealth)
                ? .save(name: state.name, endDate: state.endDate ?? .now)
                : .discard
            session?.end()
        }
    }

    private func link(to id: UUID) {
        linkedWorkoutID = id
        PhoneLink.shared.sendReliably(WatchStatus(kind: .tracking, workoutID: id))
    }

    private func scheduleRestHaptic(at endDate: Date?) {
        restTask?.cancel()
        guard let endDate, endDate > .now, isRunning else { return }
        let delay = endDate.timeIntervalSinceNow
        restTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.stop)
        }
    }

    // MARK: - Finishing

    private func finishBuilder(sessionEndDate: Date) {
        guard let builder else { reset(); return }
        let action = endAction ?? .save(name: "Strength Training", endDate: sessionEndDate)
        let linkedID = linkedWorkoutID
        let collectionStart = builder.startDate ?? sessionEndDate

        switch action {
        case .discard:
            builder.endCollection(withEnd: sessionEndDate) { _, _ in
                builder.discardWorkout()
                DispatchQueue.main.async { self.reset() }
            }
        case let .save(name, endDate):
            builder.endCollection(withEnd: max(endDate, collectionStart)) { _, _ in
                builder.addMetadata(["WorkoutName": name]) { _, _ in
                    builder.finishWorkout { workout, error in
                        if let error { print("Couldn't save workout: \(error)") }
                        DispatchQueue.main.async {
                            if workout != nil, let linkedID {
                                PhoneLink.shared.sendReliably(WatchStatus(kind: .saved, workoutID: linkedID))
                            }
                            self.reset()
                        }
                    }
                }
            }
        }
    }

    private func reset() {
        restTask?.cancel()
        session = nil
        builder = nil
        endAction = nil
        linkedWorkoutID = nil
        isRunning = false
        isPaused = false
        heartRate = 0
        activeEnergy = 0
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            self.isPaused = toState == .paused
            if toState == .ended {
                self.finishBuilder(sessionEndDate: date)
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRateType = HKQuantityType(.heartRate)
        let energyType = HKQuantityType(.activeEnergyBurned)

        let bpm = collectedTypes.contains(heartRateType)
            ? workoutBuilder.statistics(for: heartRateType)?.mostRecentQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            : nil
        let kcal = collectedTypes.contains(energyType)
            ? workoutBuilder.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            : nil

        DispatchQueue.main.async {
            if let kcal { self.activeEnergy = kcal }
            if let bpm {
                self.heartRate = bpm
                self.sendHeartRateToPhone(bpm)
            }
        }
    }

    /// Live heart rate for the iPhone screen, at most every 5 seconds.
    private func sendHeartRateToPhone(_ bpm: Double) {
        guard let linkedWorkoutID, Date().timeIntervalSince(lastHeartRateSent) >= 5 else { return }
        lastHeartRateSent = .now
        PhoneLink.shared.sendLive(WatchStatus(kind: .tracking, workoutID: linkedWorkoutID, heartRate: bpm))
    }
}
