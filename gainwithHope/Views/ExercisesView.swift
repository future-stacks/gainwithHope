import Charts
import SwiftData
import SwiftUI

struct ExercisesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var search = ""
    @State private var showNewExercise = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section(group.name) {
                        ForEach(group.exercises) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                Text(exercise.name)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(group.exercises[index]) }
                            try? context.save()
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewExercise = true
                    } label: {
                        Label("New Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewExercise) {
                NewExerciseView()
            }
        }
    }

    private var groups: [ExerciseGroup] {
        let filtered = search.isEmpty
            ? exercises
            : exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
        let grouped = Dictionary(grouping: filtered, by: \.muscleGroup)
        return grouped.keys
            .sorted { (MuscleGroup.all.firstIndex(of: $0) ?? .max) < (MuscleGroup.all.firstIndex(of: $1) ?? .max) }
            .map { ExerciseGroup(name: $0, exercises: grouped[$0] ?? []) }
    }
}

private struct ExerciseGroup: Identifiable {
    let name: String
    let exercises: [Exercise]
    var id: String { name }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    var body: some View {
        let sessions = self.sessions
        List {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Finish a workout with \(exercise.name) to see your progress.")
                )
            } else {
                Section("Personal Records") {
                    LabeledContent("Heaviest weight", value: unit.format(sessions.map(\.heaviestKg).max() ?? 0))
                    LabeledContent("Best est. 1RM", value: unit.format(sessions.map(\.bestOneRepMaxKg).max() ?? 0))
                    LabeledContent("Most reps in a set", value: "\(sessions.map(\.mostReps).max() ?? 0)")
                    LabeledContent("Sessions", value: "\(sessions.count)")
                }

                if sessions.count > 1 {
                    Section("Estimated 1RM") {
                        Chart(Array(sessions.reversed())) { session in
                            LineMark(
                                x: .value("Date", session.date),
                                y: .value("Weight", unit.fromKg(session.bestOneRepMaxKg))
                            )
                            PointMark(
                                x: .value("Date", session.date),
                                y: .value("Weight", unit.fromKg(session.bestOneRepMaxKg))
                            )
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 200)
                        .padding(.vertical, 8)
                    }
                }

                Section("History") {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            Text(session.sets.map { "\(unit.fromKg($0.weightKg).clean)×\($0.reps)" }.joined(separator: "  "))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sessions: [ExerciseSession] {
        exercise.finishedEntries.compactMap { entry in
            guard let date = entry.workout?.startDate else { return nil }
            let sets = entry.sortedSets.filter { $0.isCompleted && !$0.isWarmup }
            guard !sets.isEmpty else { return nil }
            return ExerciseSession(id: entry.persistentModelID, date: date, sets: sets)
        }
    }
}

private struct ExerciseSession: Identifiable {
    let id: PersistentIdentifier
    let date: Date
    let sets: [WorkoutSet]

    var heaviestKg: Double { sets.map(\.weightKg).max() ?? 0 }
    var bestOneRepMaxKg: Double { sets.map(\.estimatedOneRepMaxKg).max() ?? 0 }
    var mostReps: Int { sets.map(\.reps).max() ?? 0 }
}
