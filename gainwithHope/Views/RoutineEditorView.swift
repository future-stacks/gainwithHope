import SwiftData
import SwiftUI

/// Create or edit a routine. Changes are kept in a draft and only written on Save.
struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let routine: Routine?

    @State private var name: String
    @State private var weekday: Int
    @State private var notes: String
    @State private var entries: [DraftEntry]
    @State private var showPicker = false

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _weekday = State(initialValue: routine?.weekday ?? 0)
        _notes = State(initialValue: routine?.notes ?? "")
        _entries = State(initialValue: routine?.sortedEntries.compactMap { entry in
            entry.exercise.map { DraftEntry(exercise: $0, sets: entry.targetSets, repTarget: entry.repTarget) }
        } ?? [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine name, e.g. Push Day", text: $name)
                    Picker("Day", selection: $weekday) {
                        Text("Any day").tag(0)
                        // Monday first.
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                            Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                        }
                    }
                    TextField("Notes, e.g. cardio finisher", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section {
                    ForEach($entries) { $entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.exercise.name)
                            HStack {
                                Stepper("\(entry.sets) sets", value: $entry.sets, in: 1...10)
                                    .fixedSize()
                                Text("×")
                                    .foregroundStyle(.secondary)
                                TextField("reps", text: $entry.repTarget)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 110)
                            }
                            .font(.subheadline)
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
                    entries += picked.map { DraftEntry(exercise: $0, sets: 3, repTarget: "") }
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
        target.weekday = weekday
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        for (index, draft) in entries.enumerated() {
            let repTarget = draft.repTarget.trimmingCharacters(in: .whitespaces)
            let entry = RoutineExercise(order: index, targetSets: draft.sets, repTarget: repTarget)
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
    var repTarget: String
}
