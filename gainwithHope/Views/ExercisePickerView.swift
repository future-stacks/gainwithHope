import SwiftData
import SwiftUI

/// Pick one or more exercises. They're added in the order you tap them.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    var onAdd: ([Exercise]) -> Void

    @State private var search = ""
    @State private var selected: [Exercise] = []
    @State private var showNewExercise = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showNewExercise = true
                    } label: {
                        Label("Create New Exercise", systemImage: "plus.circle")
                    }
                }
                Section {
                    ForEach(filtered) { exercise in
                        Button {
                            toggle(exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    Text(exercise.muscleGroup)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let index = selected.firstIndex(of: exercise) {
                                    Image(systemName: "\(index + 1).circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Add" : "Add (\(selected.count))") {
                        onAdd(selected)
                        dismiss()
                    }
                    .bold()
                    .disabled(selected.isEmpty)
                }
            }
            .sheet(isPresented: $showNewExercise) {
                NewExerciseView(initialName: search) { exercise in
                    selected.append(exercise)
                }
            }
        }
    }

    private var filtered: [Exercise] {
        guard !search.isEmpty else { return exercises }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.muscleGroup.localizedCaseInsensitiveContains(search)
        }
    }

    private func toggle(_ exercise: Exercise) {
        if let index = selected.firstIndex(of: exercise) {
            selected.remove(at: index)
        } else {
            selected.append(exercise)
        }
    }
}

struct NewExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var onCreate: (Exercise) -> Void = { _ in }

    @State private var name: String
    @State private var muscleGroup = MuscleGroup.all[0]

    init(initialName: String = "", onCreate: @escaping (Exercise) -> Void = { _ in }) {
        _name = State(initialValue: initialName)
        self.onCreate = onCreate
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name, e.g. Cable Curl", text: $name)
                Picker("Muscle group", selection: $muscleGroup) {
                    ForEach(MuscleGroup.all, id: \.self) { Text($0).tag($0) }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exercise = Exercise(name: trimmedName, muscleGroup: muscleGroup)
                        context.insert(exercise)
                        try? context.save()
                        onCreate(exercise)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
