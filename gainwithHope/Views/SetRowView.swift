import SwiftUI

/// One row: set number | previous | weight | reps | ✓
struct SetRowView: View {
    @Bindable var set: WorkoutSet
    let label: String
    let previous: WorkoutSet?
    let unit: WeightUnit
    var onCompleted: () -> Void

    // Text-backed fields so every keystroke is saved (number-formatted TextFields
    // only commit when editing ends, which is easy to miss mid-workout).
    @State private var weightText = ""
    @State private var repsText = ""

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

            Text(previousText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { copyPrevious() }

            NumberField(text: $weightText, placeholder: previous.map { unit.fromKg($0.weightKg).clean } ?? "0", decimal: true)
                .frame(width: 64)

            NumberField(text: $repsText, placeholder: previous.map { "\($0.reps)" } ?? "0", decimal: false)
                .frame(width: 52)

            Button(action: toggleCompleted) {
                Image(systemName: set.isCompleted ? "checkmark.square.fill" : "checkmark.square")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 32)
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.15) : nil)
        .sensoryFeedback(.success, trigger: set.isCompleted) { _, completed in completed }
        .onAppear(perform: loadText)
        .onChange(of: unit) { loadText() }
        .onChange(of: weightText) { _, text in
            set.weightKg = unit.toKg(parseNumber(text) ?? 0)
        }
        .onChange(of: repsText) { _, text in
            set.reps = Int(text) ?? 0
        }
    }

    private var previousText: String {
        guard let previous else { return "—" }
        return "\(unit.format(previous.weightKg)) × \(previous.reps)"
    }

    private func loadText() {
        weightText = set.weightKg > 0 ? unit.fromKg(set.weightKg).clean : ""
        repsText = set.reps > 0 ? "\(set.reps)" : ""
    }

    private func copyPrevious() {
        guard let previous else { return }
        set.weightKg = previous.weightKg
        set.reps = previous.reps
        loadText()
    }

    private func toggleCompleted() {
        hideKeyboard()
        if !set.isCompleted, set.reps == 0, set.weightKg == 0 {
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
