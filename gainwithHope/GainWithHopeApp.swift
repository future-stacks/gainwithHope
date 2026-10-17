import SwiftData
import SwiftUI

@main
struct GainWithHopeApp: App {
    @State private var restTimer = RestTimer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(restTimer)
        }
        .modelContainer(for: [
            Exercise.self,
            Routine.self,
            RoutineExercise.self,
            Workout.self,
            WorkoutExercise.self,
            WorkoutSet.self,
        ])
    }
}
