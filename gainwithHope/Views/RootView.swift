import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(RestTimer.self) private var restTimer
    @AppStorage("saveToHealth") private var saveToHealth = true

    @Query(filter: #Predicate<Workout> { $0.endDate == nil }, sort: \Workout.startDate)
    private var activeWorkouts: [Workout]

    /// Set when the active workout screen is closing. The actual finish/discard runs
    /// after the screen is gone, so it never redraws objects we just deleted.
    @State private var pendingClose: PendingClose?

    var body: some View {
        TabView {
            StartWorkoutView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            ExercisesView()
                .tabItem { Label("Exercises", systemImage: "list.bullet") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(item: activeWorkoutBinding, onDismiss: performPendingClose) { workout in
            ActiveWorkoutView(workout: workout) { action in
                pendingClose = PendingClose(workout: workout, action: action, date: .now)
            }
            .environment(restTimer)
        }
        .task {
            SeedData.seedIfNeeded(context)
        }
    }

    private var activeWorkoutBinding: Binding<Workout?> {
        Binding(
            get: { pendingClose == nil ? activeWorkouts.first : nil },
            set: { _ in }
        )
    }

    private func performPendingClose() {
        guard let close = pendingClose else { return }
        pendingClose = nil
        restTimer.stop()

        switch close.action {
        case .discard:
            WatchBridge.shared.workoutDiscarded(id: close.workout.uuid)
            context.delete(close.workout)
            try? context.save()
        case .finish:
            let workout = close.workout
            let id = workout.uuid
            let snapshot = WorkoutSnapshot(name: workout.name, start: workout.startDate, end: close.date)
            guard context.finishWorkout(workout, at: close.date) else {
                WatchBridge.shared.workoutDiscarded(id: id)
                return
            }
            let watchSaves = WatchBridge.shared.workoutFinished(
                id: id, name: snapshot.name, endDate: close.date, saveToHealth: saveToHealth
            )
            guard saveToHealth, !watchSaves else { return }
            Task {
                do {
                    try await HealthKitManager.shared.save(snapshot)
                    workout.savedToHealth = true
                    try? context.save()
                } catch {
                    print("Couldn't save to Apple Health: \(error)")
                }
            }
        }
    }
}

enum CloseAction {
    case finish
    case discard
}

private struct PendingClose {
    let workout: Workout
    let action: CloseAction
    let date: Date
}
