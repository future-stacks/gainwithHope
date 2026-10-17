import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }

    private static let poundsPerKilogram = 2.20462262

    func fromKg(_ kg: Double) -> Double {
        self == .kg ? kg : kg * Self.poundsPerKilogram
    }

    func toKg(_ value: Double) -> Double {
        self == .kg ? value : value / Self.poundsPerKilogram
    }

    /// "82.5 kg"
    func format(_ kg: Double) -> String {
        "\(fromKg(kg).clean) \(rawValue)"
    }

    /// "12,340 kg" — for big totals like volume.
    func formatTotal(_ kg: Double) -> String {
        "\(fromKg(kg).formatted(.number.precision(.fractionLength(0)))) \(rawValue)"
    }
}

extension Double {
    /// Drops trailing zeros: 80 -> "80", 82.5 -> "82.5".
    var clean: String {
        formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

/// Parses user input, accepting either "." or "," as the decimal separator.
func parseNumber(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
}

/// "4:05" or "1:02:09"
func formatClock(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.down)))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%d:%02d", m, s)
}

/// "1h 12m" or "45m"
func formatDuration(_ interval: TimeInterval) -> String {
    let minutes = max(0, Int(interval / 60))
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}
