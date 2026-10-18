import Foundation

// Messages passed between the iPhone and Apple Watch apps over WatchConnectivity.
// Compiled into both targets.

/// The iPhone's current workout, as the watch sees it.
struct PhoneWorkoutState: Codable, Equatable {
    enum Phase: String, Codable {
        case active
        case finished
        case discarded
    }

    var id: UUID
    var phase: Phase
    var name: String
    var startDate: Date
    var endDate: Date?
    var currentExercise: String?
    var setProgress: String?
    var restEndDate: Date?
    var saveToHealth: Bool
    /// Makes every update unique, so application context changes are always delivered.
    var sentAt: Date = .now
}

/// What the watch reports back to the iPhone.
struct WatchStatus: Codable {
    enum Kind: String, Codable {
        /// The watch is recording this iPhone workout (sent with live heart rate).
        case tracking
        /// The watch saved this workout to Apple Health.
        case saved
    }

    var kind: Kind
    var workoutID: UUID
    var heartRate: Double?
}

enum WatchLink {
    private static let key = "payload"

    static func encode<T: Encodable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value) else { return [:] }
        return [key: data]
    }

    static func decode<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]) -> T? {
        guard let data = dictionary[key] as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
