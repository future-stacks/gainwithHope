import Foundation
import SwiftData

enum MuscleGroup {
    static let all = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Legs", "Glutes", "Core", "Full Body", "Cardio", "Other"]
}

enum SeedData {
    private static let exercises: [(String, String)] = [
        ("Bench Press (Barbell)", "Chest"),
        ("Incline Bench Press (Barbell)", "Chest"),
        ("Bench Press (Dumbbell)", "Chest"),
        ("Incline Bench Press (Dumbbell)", "Chest"),
        ("Chest Fly (Cable)", "Chest"),
        ("Chest Dip", "Chest"),
        ("Push Up", "Chest"),
        ("Deadlift (Barbell)", "Back"),
        ("Pull Up", "Back"),
        ("Chin Up", "Back"),
        ("Lat Pulldown (Cable)", "Back"),
        ("Bent Over Row (Barbell)", "Back"),
        ("Seated Row (Cable)", "Back"),
        ("Dumbbell Row", "Back"),
        ("T-Bar Row", "Back"),
        ("Overhead Press (Barbell)", "Shoulders"),
        ("Shoulder Press (Dumbbell)", "Shoulders"),
        ("Lateral Raise (Dumbbell)", "Shoulders"),
        ("Face Pull (Cable)", "Shoulders"),
        ("Rear Delt Fly (Dumbbell)", "Shoulders"),
        ("Bicep Curl (Barbell)", "Biceps"),
        ("Bicep Curl (Dumbbell)", "Biceps"),
        ("Hammer Curl (Dumbbell)", "Biceps"),
        ("Preacher Curl", "Biceps"),
        ("Triceps Pushdown (Cable)", "Triceps"),
        ("Overhead Triceps Extension", "Triceps"),
        ("Skullcrusher (Barbell)", "Triceps"),
        ("Close Grip Bench Press", "Triceps"),
        ("Squat (Barbell)", "Legs"),
        ("Front Squat (Barbell)", "Legs"),
        ("Leg Press", "Legs"),
        ("Romanian Deadlift (Barbell)", "Legs"),
        ("Bulgarian Split Squat", "Legs"),
        ("Lunge (Dumbbell)", "Legs"),
        ("Leg Extension (Machine)", "Legs"),
        ("Leg Curl (Machine)", "Legs"),
        ("Calf Raise (Machine)", "Legs"),
        ("Hip Thrust (Barbell)", "Glutes"),
        ("Glute Bridge", "Glutes"),
        ("Plank", "Core"),
        ("Hanging Leg Raise", "Core"),
        ("Cable Crunch", "Core"),
        ("Ab Wheel Rollout", "Core"),
        ("Kettlebell Swing", "Full Body"),
        ("Clean and Press", "Full Body"),
    ]

    // MARK: - 8-week machine programme

    private struct PlanExercise {
        let name: String
        let muscleGroup: String
        let sets: Int
        let reps: String
    }

    private struct PlanDay {
        let name: String
        /// Calendar weekday: 2 = Monday … 6 = Friday.
        let weekday: Int
        let notes: String
        let exercises: [PlanExercise]
    }

    private static let finisher = """
        Finisher: 20 min StairMaster / incline walk (~125–145 bpm).
        Rest 1–2 min between sets. Last 2–3 reps hard, form clean, lower each rep ~3 s. \
        Top of rep range on all sets → add weight.
        """

    private static let trainingPlan: [PlanDay] = [
        PlanDay(name: "Lower A · Glutes", weekday: 2, notes: "Leg press: feet high & wide.\n" + finisher, exercises: [
            PlanExercise(name: "Hip Thrust (Machine)", muscleGroup: "Glutes", sets: 4, reps: "8–10"),
            PlanExercise(name: "Leg Press", muscleGroup: "Legs", sets: 3, reps: "10–12"),
            PlanExercise(name: "45° Back Extension", muscleGroup: "Glutes", sets: 3, reps: "12–15"),
            PlanExercise(name: "Seated Hip Abduction (Machine)", muscleGroup: "Glutes", sets: 3, reps: "15–20"),
            PlanExercise(name: "Plank", muscleGroup: "Core", sets: 3, reps: "45s"),
        ]),
        PlanDay(name: "Upper A", weekday: 3, notes: finisher, exercises: [
            PlanExercise(name: "Chest Press (Machine)", muscleGroup: "Chest", sets: 3, reps: "8–10"),
            PlanExercise(name: "Lat Pulldown (Cable)", muscleGroup: "Back", sets: 3, reps: "10–12"),
            PlanExercise(name: "Seated Row (Machine)", muscleGroup: "Back", sets: 3, reps: "10–12"),
            PlanExercise(name: "Lateral Raise (Machine)", muscleGroup: "Shoulders", sets: 3, reps: "12–15"),
            PlanExercise(name: "Ab Crunch (Machine)", muscleGroup: "Core", sets: 3, reps: "12–15"),
        ]),
        PlanDay(name: "Lower B · Glutes & Legs", weekday: 5, notes: "Hack squat or leg press for the first lift.\n" + finisher, exercises: [
            PlanExercise(name: "Hack Squat", muscleGroup: "Legs", sets: 4, reps: "8–10"),
            PlanExercise(name: "Glute Kickback (Machine)", muscleGroup: "Glutes", sets: 3, reps: "12–15 ea"),
            PlanExercise(name: "Reverse Lunge (Smith Machine)", muscleGroup: "Legs", sets: 3, reps: "10 ea"),
            PlanExercise(name: "Seated Leg Curl (Machine)", muscleGroup: "Legs", sets: 3, reps: "10–12"),
            PlanExercise(name: "Captain's Chair Knee Raise", muscleGroup: "Core", sets: 3, reps: "10–12"),
        ]),
        PlanDay(name: "Upper B", weekday: 6, notes: finisher, exercises: [
            PlanExercise(name: "Shoulder Press (Machine)", muscleGroup: "Shoulders", sets: 3, reps: "8–10"),
            PlanExercise(name: "Chest-Supported Row", muscleGroup: "Back", sets: 3, reps: "10–12"),
            PlanExercise(name: "Incline Chest Press (Machine)", muscleGroup: "Chest", sets: 3, reps: "10"),
            PlanExercise(name: "Rear Delt Fly (Pec Deck)", muscleGroup: "Shoulders", sets: 3, reps: "15"),
            PlanExercise(name: "Plank", muscleGroup: "Core", sets: 3, reps: "45s"),
        ]),
    ]

    /// Adds the training plan as routines, once. Deleting them later won't bring them back.
    static func seedTrainingPlanIfNeeded(_ context: ModelContext) {
        let key = "seededTrainingPlanV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        var exercisesByName: [String: Exercise] = [:]
        for exercise in (try? context.fetch(FetchDescriptor<Exercise>())) ?? [] {
            exercisesByName[exercise.name.lowercased()] = exercise
        }

        for (dayIndex, day) in trainingPlan.enumerated() {
            let routine = Routine(name: day.name)
            // Keep Mon → Fri order in the routine list.
            routine.createdAt = Date().addingTimeInterval(TimeInterval(dayIndex))
            routine.notes = day.notes
            routine.weekday = day.weekday
            context.insert(routine)

            for (order, item) in day.exercises.enumerated() {
                let exercise: Exercise
                if let existing = exercisesByName[item.name.lowercased()] {
                    exercise = existing
                } else {
                    exercise = Exercise(name: item.name, muscleGroup: item.muscleGroup)
                    context.insert(exercise)
                    exercisesByName[item.name.lowercased()] = exercise
                }
                let entry = RoutineExercise(order: order, targetSets: item.sets, repTarget: item.reps)
                context.insert(entry)
                entry.exercise = exercise
                routine.entries.append(entry)
            }
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else { return }
        for (name, group) in exercises {
            context.insert(Exercise(name: name, muscleGroup: group))
        }
        try? context.save()
    }
}
