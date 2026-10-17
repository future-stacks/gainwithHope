import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate, order: .reverse)
    private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutRow(workout: workout, unit: unit)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(workouts[index]) }
                    try? context.save()
                }
            }
            .navigationTitle("History")
            .overlay {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "dumbbell",
                        description: Text("Finished workouts show up here.")
                    )
                }
            }
        }
    }
}

private struct WorkoutRow: View {
    let workout: Workout
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(workout.name)
                    .font(.headline)
                if workout.savedToHealth {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                }
            }
            Text(workout.startDate.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Label(formatDuration(workout.duration), systemImage: "clock")
                Label(unit.formatTotal(workout.totalVolumeKg), systemImage: "scalemass")
                Label("\(workout.completedSets.count) sets", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(workout.sortedExercises.map(\.displayName).joined(separator: ", "))
                .font(.subheadline)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    @State private var savingToHealth = false
    @State private var healthError: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: workout.startDate.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: formatDuration(workout.duration))
                LabeledContent("Volume", value: unit.formatTotal(workout.totalVolumeKg))
                LabeledContent("Sets", value: "\(workout.completedSets.count)")
                if !workout.notes.isEmpty {
                    Text(workout.notes)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(workout.sortedExercises) { entry in
                Section(entry.displayName) {
                    ForEach(Array(entry.sortedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text(set.isWarmup ? "W" : "\(index + 1)")
                                .foregroundStyle(set.isWarmup ? Color.orange : Color.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text("\(unit.format(set.weightKg)) × \(set.reps)")
                                .monospacedDigit()
                            Spacer()
                            if set.estimatedOneRepMaxKg > 0, !set.isWarmup {
                                Text("1RM \(unit.format(set.estimatedOneRepMaxKg))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                if workout.savedToHealth {
                    Label("Saved to Apple Health", systemImage: "heart.fill")
                        .foregroundStyle(.pink)
                } else {
                    Button {
                        Task { await saveToHealth() }
                    } label: {
                        if savingToHealth {
                            ProgressView()
                        } else {
                            Label("Save to Apple Health", systemImage: "heart")
                        }
                    }
                    .disabled(savingToHealth)
                }
            } footer: {
                if let healthError {
                    Text(healthError).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveToHealth() async {
        guard let end = workout.endDate else { return }
        savingToHealth = true
        defer { savingToHealth = false }
        do {
            try await HealthKitManager.shared.save(WorkoutSnapshot(name: workout.name, start: workout.startDate, end: end))
            workout.savedToHealth = true
            healthError = nil
        } catch {
            healthError = error.localizedDescription
        }
    }
}
