import Foundation
import HealthKit

/// Plain copy of a finished workout, so HealthKit work doesn't touch SwiftData objects.
struct WorkoutSnapshot {
    let name: String
    let start: Date
    let end: Date
}

enum HealthKitError: LocalizedError {
    case unavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Apple Health isn't available on this device."
        case .notAuthorized: return "gainwithHope isn't allowed to save workouts. Turn it on in Settings › Health › Data Access & Devices."
        }
    }
}

/// Saves finished workouts to Apple Health as Traditional Strength Training,
/// so they show up in the Fitness app and count toward your rings.
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
    }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.bodyMass)]
    }

    var canSaveWorkouts: Bool {
        isAvailable && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    /// Shows the Health permission sheet the first time; does nothing after that.
    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func save(_ workout: WorkoutSnapshot) async throws {
        try await requestAuthorization()
        guard canSaveWorkouts else { throw HealthKitError.notAuthorized }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: workout.start) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }

        if let energy = await estimatedActiveEnergy(for: workout) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add([energy]) { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.addMetadata([HKMetadataKeyIndoorWorkout: true, "WorkoutName": workout.name]) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: workout.end) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.finishWorkout { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    /// Rough calorie estimate for weight training (~3.5 METs, minus the 1 MET you burn at rest),
    /// using your latest body weight from Health. Skipped if Health has no body weight.
    private func estimatedActiveEnergy(for workout: WorkoutSnapshot) async -> HKQuantitySample? {
        guard let bodyMassKg = await latestBodyMassKg() else { return nil }
        let hours = workout.end.timeIntervalSince(workout.start) / 3600
        let kilocalories = 2.5 * bodyMassKg * hours
        guard kilocalories > 0 else { return nil }
        return HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kilocalories),
            start: workout.start,
            end: workout.end
        )
    }

    private func latestBodyMassKg() async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let samples = try? await descriptor.result(for: store)
        return samples?.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }
}
