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
    @Bindable var exercise: Exercise
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    var body: some View {
        let sessions = self.sessions
        let tracking = exercise.tracking
        List {
            Section {
                Picker("Log as", selection: $exercise.tracking) {
                    ForEach(ExerciseTracking.allCases) { Text($0.label).tag($0) }
                }
            }

            if sessions.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Finish a workout with \(exercise.name) to see your progress.")
                )
            } else {
                Section("Personal Records") {
                    switch tracking {
                    case .weightReps:
                        LabeledContent("Heaviest weight", value: unit.format(sessions.map(\.heaviestKg).max() ?? 0))
                        LabeledContent("Best est. 1RM", value: unit.format(sessions.map(\.bestOneRepMaxKg).max() ?? 0))
                        LabeledContent("Most reps in a set", value: "\(sessions.map(\.mostReps).max() ?? 0)")
                    case .time:
                        LabeledContent("Longest hold", value: formatSeconds(sessions.map(\.longestSeconds).max() ?? 0))
                    case .cardio:
                        LabeledContent("Longest session", value: formatDuration(TimeInterval(sessions.map(\.totalSeconds).max() ?? 0)))
                        LabeledContent("Furthest distance", value: "\((sessions.map(\.totalKm).max() ?? 0).clean) km")
                    }
                    LabeledContent("Sessions", value: "\(sessions.count)")
                }

                if sessions.count > 1 {
                    Section(chartTitle(tracking)) {
                        Chart(Array(sessions.reversed())) { session in
                            LineMark(
                                x: .value("Date", session.date),
                                y: .value("Value", chartValue(session, tracking))
                            )
                            PointMark(
                                x: .value("Date", session.date),
                                y: .value("Value", chartValue(session, tracking))
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
                            Text(session.sets.map { $0.summary(tracking, unit: unit) }.joined(separator: ",  "))
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

    private func chartTitle(_ tracking: ExerciseTracking) -> String {
        switch tracking {
        case .weightReps: return "Estimated 1RM (\(unit.rawValue))"
        case .time: return "Longest hold (seconds)"
        case .cardio: return "Minutes per session"
        }
    }

    private func chartValue(_ session: ExerciseSession, _ tracking: ExerciseTracking) -> Double {
        switch tracking {
        case .weightReps: return unit.fromKg(session.bestOneRepMaxKg)
        case .time: return Double(session.longestSeconds)
        case .cardio: return Double(session.totalSeconds) / 60
        }
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
    var longestSeconds: Int { sets.map(\.durationSeconds).max() ?? 0 }
    var totalSeconds: Int { sets.reduce(0) { $0 + $1.durationSeconds } }
    var totalKm: Double { sets.reduce(0) { $0 + $1.distanceKm } }
}
