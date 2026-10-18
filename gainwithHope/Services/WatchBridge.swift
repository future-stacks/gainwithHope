import Foundation
import HealthKit
import Observation
import SwiftData
import WatchConnectivity

/// iPhone side of the Apple Watch connection.
///
/// Starting a workout launches the watch app, which runs a real workout session
/// (live heart rate, calories, Exercise ring). When the iPhone workout finishes,
/// the watch ends its session and saves the workout to Apple Health.
@Observable
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    /// Live heart rate from the watch, while it's tracking the current workout.
    private(set) var heartRate: Int?

    @ObservationIgnored var modelContext: ModelContext?
    @ObservationIgnored private let healthStore = HKHealthStore()

    // Persisted so a workout restored after the app is closed still links up with the watch.
    @ObservationIgnored private var phoneState: PhoneWorkoutState? {
        didSet { save(phoneState, forKey: "watch.phoneState") }
    }
    @ObservationIgnored private var trackingWorkoutID: UUID? {
        didSet { UserDefaults.standard.set(trackingWorkoutID?.uuidString, forKey: "watch.trackingID") }
    }

    override init() {
        super.init()
        phoneState = load(PhoneWorkoutState.self, forKey: "watch.phoneState")
        trackingWorkoutID = UserDefaults.standard.string(forKey: "watch.trackingID").flatMap(UUID.init(uuidString:))
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "useWatch") as? Bool ?? true
    }

    private var watchAvailable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Workout lifecycle (called by the iPhone UI)

    func workoutStarted(_ workout: Workout) {
        guard isEnabled, watchAvailable else { return }
        heartRate = nil
        trackingWorkoutID = nil
        phoneState = PhoneWorkoutState(
            id: workout.uuid,
            phase: .active,
            name: workout.name,
            startDate: workout.startDate,
            saveToHealth: UserDefaults.standard.object(forKey: "saveToHealth") as? Bool ?? true
        )
        workoutProgressed(workout)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        healthStore.startWatchApp(with: configuration) { _, error in
            if let error { print("Couldn't launch the watch app: \(error)") }
        }
    }

    /// Tells the watch which exercise and set you're on.
    func workoutProgressed(_ workout: Workout) {
        guard var state = phoneState, state.id == workout.uuid, state.phase == .active else { return }
        let current = workout.sortedExercises.first { entry in entry.sets.contains { !$0.isCompleted } }
        state.name = workout.name
        state.currentExercise = current?.displayName
        if let current {
            let done = current.sets.filter(\.isCompleted).count
            state.setProgress = "Set \(done + 1) of \(current.sets.count)"
        } else {
            state.setProgress = nil
        }
        state.sentAt = .now
        phoneState = state
        send()
    }

    /// The watch taps your wrist when rest is over.
    func restTimerChanged(endDate: Date?) {
        guard var state = phoneState, state.phase == .active else { return }
        state.restEndDate = endDate
        state.sentAt = .now
        phoneState = state
        send()
    }

    /// Returns true if the watch is recording this workout and will save it to Apple Health itself.
    func workoutFinished(id: UUID, name: String, endDate: Date, saveToHealth: Bool) -> Bool {
        let watchIsTracking = trackingWorkoutID == id
        if var state = phoneState, state.id == id {
            state.phase = .finished
            state.name = name
            state.endDate = endDate
            state.saveToHealth = saveToHealth
            state.restEndDate = nil
            state.sentAt = .now
            phoneState = state
            send()
        }
        trackingWorkoutID = nil
        heartRate = nil
        return watchIsTracking
    }

    func workoutDiscarded(id: UUID) {
        if var state = phoneState, state.id == id {
            state.phase = .discarded
            state.sentAt = .now
            phoneState = state
            send()
        }
        trackingWorkoutID = nil
        heartRate = nil
    }

    private func send() {
        guard let phoneState, watchAvailable else { return }
        let payload = WatchLink.encode(phoneState)
        try? WCSession.default.updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil)
        }
    }

    // MARK: - Messages from the watch

    private func handle(_ dictionary: [String: Any]) {
        guard let status = WatchLink.decode(WatchStatus.self, from: dictionary) else { return }
        DispatchQueue.main.async {
            switch status.kind {
            case .tracking:
                guard self.phoneState?.id == status.workoutID, self.phoneState?.phase == .active else { return }
                self.trackingWorkoutID = status.workoutID
                if let bpm = status.heartRate, bpm > 0 { self.heartRate = Int(bpm.rounded()) }
            case .saved:
                self.markSavedToHealth(status.workoutID)
            }
        }
    }

    private func markSavedToHealth(_ id: UUID) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.uuid == id })
        guard let workout = try? modelContext.fetch(descriptor).first else { return }
        workout.savedToHealth = true
        try? modelContext.save()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Switching to a different watch: reconnect to the new one.
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    // MARK: - Persistence helpers

    private func save<T: Encodable>(_ value: T?, forKey key: String) {
        UserDefaults.standard.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
