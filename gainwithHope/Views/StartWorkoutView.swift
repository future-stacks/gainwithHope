import SwiftData
import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query(filter: #Predicate<Workout> { $0.endDate != nil }) private var finishedWorkouts: [Workout]

    @State private var editor: RoutineEditorTarget?

    var body: some View {
        NavigationStack {
            List {
                if routines.contains(where: { $0.weekday != 0 }) {
                    Section("Today") {
                        if let routine = todaysRoutine {
                            Button {
                                start(routine)
                            } label: {
                                HStack {
                                    RoutineRow(routine: routine)
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(.tint)
                                }
                            }
                        } else {
                            Label("Rest day: get your steps in", systemImage: "figure.walk")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        start(nil)
                    } label: {
                        Label("Start Empty Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                } footer: {
                    Text(weekSummary)
                }

                Section {
                    ForEach(routines) { routine in
                        Button {
                            start(routine)
                        } label: {
                            RoutineRow(routine: routine)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(routine)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editor = RoutineEditorTarget(routine: routine)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button {
                                editor = RoutineEditorTarget(routine: routine)
                            } label: {
                                Label("Edit Routine", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                context.delete(routine)
                            } label: {
                                Label("Delete Routine", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("My Routines")
                } footer: {
                    if routines.isEmpty {
                        Text("Save workouts you repeat (like Push Day or Leg Day) as routines. Tap + to make one.")
                    } else {
                        Text("Tap a routine to start it. Swipe for edit and delete.")
                    }
                }
            }
            .navigationTitle("Workout")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = RoutineEditorTarget(routine: nil)
                    } label: {
                        Label("New Routine", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editor) { target in
                RoutineEditorView(routine: target.routine)
            }
        }
    }

    private func start(_ routine: Routine?) {
        let workout = context.startWorkout(from: routine)
        WatchBridge.shared.workoutStarted(workout)
    }

    private var todaysRoutine: Routine? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return routines.first { $0.weekday == weekday }
    }

    private var weekSummary: String {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start else { return "" }
        let count = finishedWorkouts.filter { $0.startDate >= weekStart }.count
        return count == 1 ? "1 workout this week" : "\(count) workouts this week"
    }
}

private struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let day = routine.weekdayLabel {
                    Text(day)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                }
                Text(routine.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            Text(routine.sortedEntries.compactMap { $0.exercise?.name }.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 2)
    }
}

private struct RoutineEditorTarget: Identifiable {
    let id = UUID()
    let routine: Routine?
}
