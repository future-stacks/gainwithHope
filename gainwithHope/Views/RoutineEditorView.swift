import SwiftData
import SwiftUI

/// Create or edit a routine. Changes are kept in a draft and only written on Save.
struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let routine: Routine?

    @State private var name: String
    @State private var entries: [DraftEntry]
    @State private var showPicker = false

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _entries = State(initialValue: routine?.sortedEntries.compactMap { entry in
            entry.exercise.map { DraftEntry(exercise: $0, sets: entry.targetSets) }
        } ?? [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine name, e.g. Push Day", text: $name)
                }
                Section {
                    ForEach($entries) { $entry in
                        Stepper(value: $entry.sets, in: 1...10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.exercise.name)
                                Text("\(entry.sets) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { entries.remove(atOffsets: $0) }
                    .onMove { entries.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        if entries.count > 1 {
                            EditButton()
                                .font(.caption)
                                .textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(trimmedName.isEmpty || entries.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { picked in
                    entries += picked.map { DraftEntry(exercise: $0, sets: 3) }
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let target: Routine
        if let routine {
            target = routine
            let old = routine.entries
            routine.entries.removeAll()
            for entry in old { context.delete(entry) }
            routine.name = trimmedName
        } else {
            target = Routine(name: trimmedName)
            context.insert(target)
        }
        for (index, draft) in entries.enumerated() {
            let entry = RoutineExercise(order: index, targetSets: draft.sets)
            context.insert(entry)
            entry.exercise = draft.exercise
            target.entries.append(entry)
        }
        try? context.save()
        dismiss()
    }
}

private struct DraftEntry: Identifiable {
    let id = UUID()
    let exercise: Exercise
    var sets: Int
}
