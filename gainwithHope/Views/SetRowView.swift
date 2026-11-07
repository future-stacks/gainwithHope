import SwiftUI

/// One row: set number | previous | two inputs | ✓
/// The inputs depend on the exercise: weight + reps, seconds, or minutes + km.
struct SetRowView: View {
    @Bindable var set: WorkoutSet
    let label: String
    let previous: WorkoutSet?
    let tracking: ExerciseTracking
    let unit: WeightUnit
    var onCompleted: () -> Void

    // Text-backed fields so every keystroke is saved (number-formatted TextFields
    // only commit when editing ends, which is easy to miss mid-workout).
    @State private var firstText = ""
    @State private var secondText = ""

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Button(set.isWarmup ? "Make Working Set" : "Make Warm-up Set") {
                    set.isWarmup.toggle()
                }
            } label: {
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(set.isWarmup ? Color.orange : Color.primary)
                    .frame(width: 30)
            }

            Text(previous?.summary(tracking, unit: unit) ?? "—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { copyPrevious() }

            NumberField(text: $firstText, placeholder: placeholders.first, decimal: tracking != .time)
                .frame(width: 64)

            if tracking == .time {
                Color.clear.frame(width: 52, height: 1)
            } else {
                NumberField(text: $secondText, placeholder: placeholders.second, decimal: tracking == .cardio)
                    .frame(width: 52)
            }

            Button(action: toggleCompleted) {
                Image(systemName: set.isCompleted ? "checkmark.square.fill" : "checkmark.square")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 32)
        }
        .listRowBackground(set.isCompleted ? Color.accentColor.opacity(0.18) : nil)
        .sensoryFeedback(.success, trigger: set.isCompleted) { _, completed in completed }
        .onAppear(perform: loadText)
        .onChange(of: unit) { loadText() }
        .onChange(of: firstText) { _, text in
            switch tracking {
            case .weightReps: set.weightKg = unit.toKg(parseNumber(text) ?? 0)
            case .time: set.durationSeconds = Int(text) ?? 0
            case .cardio: set.durationSeconds = Int(((parseNumber(text) ?? 0) * 60).rounded())
            }
        }
        .onChange(of: secondText) { _, text in
            switch tracking {
            case .weightReps: set.reps = Int(text) ?? 0
            case .time: break
            case .cardio: set.distanceKm = parseNumber(text) ?? 0
            }
        }
    }

    private var placeholders: (first: String, second: String) {
        switch tracking {
        case .weightReps:
            return (previous.map { unit.fromKg($0.weightKg).clean } ?? "0", previous.map { "\($0.reps)" } ?? "0")
        case .time:
            return (previous.map { "\($0.durationSeconds)" } ?? "0", "")
        case .cardio:
            return (previous.map { (Double($0.durationSeconds) / 60).clean } ?? "0", previous.map { $0.distanceKm.clean } ?? "–")
        }
    }

    private var isEmpty: Bool {
        return set.weightKg == 0 && set.reps == 0 && set.durationSeconds == 0 && set.distanceKm == 0
    }

    private func loadText() {
        switch tracking {
        case .weightReps:
            firstText = set.weightKg > 0 ? unit.fromKg(set.weightKg).clean : ""
            secondText = set.reps > 0 ? "\(set.reps)" : ""
        case .time:
            firstText = set.durationSeconds > 0 ? "\(set.durationSeconds)" : ""
            secondText = ""
        case .cardio:
            firstText = set.durationSeconds > 0 ? (Double(set.durationSeconds) / 60).clean : ""
            secondText = set.distanceKm > 0 ? set.distanceKm.clean : ""
        }
    }

    private func copyPrevious() {
        guard let previous else { return }
        set.weightKg = previous.weightKg
        set.reps = previous.reps
        set.durationSeconds = previous.durationSeconds
        set.distanceKm = previous.distanceKm
        loadText()
    }

    private func toggleCompleted() {
        hideKeyboard()
        if !set.isCompleted, isEmpty {
            copyPrevious()
        }
        set.isCompleted.toggle()
        if set.isCompleted { onCompleted() }
    }
}

private struct NumberField: View {
    @Binding var text: String
    let placeholder: String
    let decimal: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(.body.monospacedDigit().weight(.medium))
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
    }
}
