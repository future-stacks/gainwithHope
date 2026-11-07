import SwiftData
import SwiftUI

/// Edit a finished workout, or log a past one: name, times, notes, exercises and sets.
/// Changes are saved as you make them.
struct WorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var workout: Workout
    /// Set when logging a past workout; Cancel throws it away.
    var onCancel: (() -> Void)?

    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $workout.name)
                        .font(.title3.bold())
                    DatePicker("Started", selection: $workout.startDate)
                    DatePicker("Finished", selection: endDate, in: workout.startDate...)
                    TextField("Notes", text: $workout.notes, axis: .vertical)
                } footer: {
                    if workout.savedToHealth {
                        Text("Already saved to Apple Health. Edits here update gainwithHope only.")
                    }
                }

                ForEach(workout.sortedExercises) { entry in
                    ExerciseSection(
                        entry: entry,
                        workout: workout,
                        unit: unit,
                        newSetsCompleted: true,
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
                } footer: {
                    Text("Swipe a set left to delete it. Use ⋯ next to an exercise to remove it.")
                }
            }
            .listSectionSpacing(.compact)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(onCancel == nil ? "Edit Workout" : "Log Past Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exercises in add(exercises) }
            }
        }
    }

    private var endDate: Binding<Date> {
        Binding(
            get: { workout.endDate ?? workout.startDate },
            set: { workout.endDate = max($0, workout.startDate) }
        )
    }

    private func add(_ exercises: [Exercise]) {
        var order = (workout.exercises.map(\.order).max() ?? -1) + 1
        for exercise in exercises {
            let entry = context.addExercise(exercise, to: workout, order: order)
            // A finished workout only keeps ticked sets, so new ones start ticked.
            for set in entry.sets { set.isCompleted = true }
            order += 1
        }
    }

    private func remove(_ entry: WorkoutExercise) {
        workout.exercises.removeAll { $0 == entry }
        context.delete(entry)
    }
}
