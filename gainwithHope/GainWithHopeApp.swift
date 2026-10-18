import SwiftData
import SwiftUI

@main
struct GainWithHopeApp: App {
    @State private var restTimer = RestTimer()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Exercise.self, Routine.self, RoutineExercise.self,
                Workout.self, WorkoutExercise.self, WorkoutSet.self
            )
        } catch {
            fatalError("Couldn't open the workout database: \(error)")
        }
        WatchBridge.shared.modelContext = container.mainContext
        WatchBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(restTimer)
        }
        .modelContainer(container)
    }
}
