import SwiftData
import SwiftUI
import UIKit

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(RestTimer.self) private var restTimer
    @Bindable var workout: Workout
    var onClose: (CloseAction) -> Void

    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @AppStorage("restSeconds") private var restSeconds = 90
    @AppStorage("autoRestTimer") private var autoRestTimer = true

    @State private var showPicker = false
    @State private var confirmFinish = false
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $workout.name)
                        .font(.title2.bold())
                    HStack {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Label(formatClock(context.date.timeIntervalSince(workout.startDate)), systemImage: "timer")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let heartRate = WatchBridge.shared.heartRate {
                            Label("\(heartRate) BPM", systemImage: "heart.fill")
                                .monospacedDigit()
                                .foregroundStyle(.pink)
                        }
                    }
                    TextField("Notes", text: $workout.notes, axis: .vertical)
                }

                ForEach(workout.sortedExercises) { entry in
                    ExerciseSection(
                        entry: entry,
                        workout: workout,
                        unit: unit,
                        onSetCompleted: {
                            if autoRestTimer { restTimer.start(seconds: restSeconds) }
                            WatchBridge.shared.workoutProgressed(workout)
                        },
                        onRemove: { remove(entry) }
                    )
                }

                Section {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    Button(role: .destructive) {
                        confirmDiscard = true
                    } label: {
                        Text("Cancel Workout")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .listSectionSpacing(.compact)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if restTimer.isRunning {
                    RestTimerBar()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        restTimer.isRunning ? restTimer.stop() : restTimer.start(seconds: restSeconds)
                    } label: {
                        Image(systemName: restTimer.isRunning ? "timer.circle.fill" : "timer")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { confirmFinish = true }
                        .bold()
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exercises in add(exercises) }
            }
            .alert(finishTitle, isPresented: $confirmFinish) {
                Button("Finish") { onClose(.finish) }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text(finishMessage)
            }
            .confirmationDialog("Cancel this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) { onClose(.discard) }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Everything you logged in this workout will be deleted.")
            }
        }
    }

    private var completedCount: Int { workout.completedSets.count }
    private var unfinishedCount: Int { workout.exercises.flatMap(\.sets).count - completedCount }

    private var finishTitle: String {
        completedCount == 0 ? "No sets completed" : "Finish workout?"
    }

    private var finishMessage: String {
        if completedCount == 0 {
            return "You haven't ticked off any sets, so nothing will be saved."
        }
        var message = "\(completedCount) sets · \(unit.formatTotal(workout.totalVolumeKg)) total."
        if unfinishedCount > 0 {
            message += " \(unfinishedCount) unticked sets will be removed."
        }
        return message
    }

    private func add(_ exercises: [Exercise]) {
        var order = (workout.exercises.map(\.order).max() ?? -1) + 1
        for exercise in exercises {
            context.addExercise(exercise, to: workout, order: order)
            order += 1
        }
        WatchBridge.shared.workoutProgressed(workout)
    }

    private func remove(_ entry: WorkoutExercise) {
        workout.exercises.removeAll { $0 == entry }
        context.delete(entry)
    }
}

private struct ExerciseSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: WorkoutExercise
    let workout: Workout
    let unit: WeightUnit
    var onSetCompleted: () -> Void
    var onRemove: () -> Void

    var body: some View {
        let sets = entry.sortedSets
        let previous = entry.exercise?.lastCompletedEntry(excluding: workout)?.sortedSets.filter(\.isCompleted) ?? []
        let numbers = setNumbers(for: sets)

        Section {
            SetHeaderRow(unit: unit)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                SetRowView(
                    set: set,
                    label: numbers[index],
                    previous: previous.indices.contains(index) ? previous[index] : nil,
                    unit: unit,
                    onCompleted: onSetCompleted
                )
            }
            .onDelete { offsets in
                let doomed = offsets.map { sets[$0] }
                entry.sets.removeAll { doomed.contains($0) }
                for set in doomed { context.delete(set) }
            }

            Button {
                addSet(after: sets.last)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.headline)
                        .foregroundStyle(.tint)
                    if !entry.repTarget.isEmpty {
                        Text("Target: \(entry.repTarget)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .textCase(nil)
                Spacer()
                Menu {
                    Button {
                        addSet(after: nil, warmup: true)
                    } label: {
                        Label("Add Warm-up Set", systemImage: "flame")
                    }
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
    }

    /// Warm-ups show "W"; working sets are numbered 1, 2, 3…
    private func setNumbers(for sets: [WorkoutSet]) -> [String] {
        var n = 0
        return sets.map { set in
            if set.isWarmup { return "W" }
            n += 1
            return "\(n)"
        }
    }

    private func addSet(after last: WorkoutSet?, warmup: Bool = false) {
        let order = warmup
            ? (entry.sets.map(\.order).min() ?? 0) - 1
            : (entry.sets.map(\.order).max() ?? -1) + 1
        let set = WorkoutSet(
            order: order,
            weightKg: last?.weightKg ?? 0,
            reps: last?.reps ?? 0,
            isWarmup: warmup
        )
        context.insert(set)
        entry.sets.append(set)
    }
}

private struct SetHeaderRow: View {
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 10) {
            Text("SET").frame(width: 30)
            Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
            Text(unit.rawValue.uppercased()).frame(width: 64)
            Text("REPS").frame(width: 52)
            Image(systemName: "checkmark").frame(width: 32)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
