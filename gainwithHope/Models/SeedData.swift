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

    // MARK: - Library v2: cardio, timed holds, more machines

    private static let libraryV2: [(String, String, ExerciseTracking)] = [
        // Cardio
        ("StairMaster", "Cardio", .cardio),
        ("Treadmill Incline Walk", "Cardio", .cardio),
        ("Treadmill Run", "Cardio", .cardio),
        ("Stationary Bike", "Cardio", .cardio),
        ("Spin Bike", "Cardio", .cardio),
        ("Elliptical", "Cardio", .cardio),
        ("Rowing Machine", "Cardio", .cardio),
        ("Assault Bike", "Cardio", .cardio),
        ("SkiErg", "Cardio", .cardio),
        ("Jump Rope", "Cardio", .cardio),
        ("Outdoor Walk", "Cardio", .cardio),
        ("Outdoor Run", "Cardio", .cardio),
        // Timed holds
        ("Plank", "Core", .time),
        ("Side Plank", "Core", .time),
        ("Hollow Hold", "Core", .time),
        ("Wall Sit", "Legs", .time),
        ("Dead Hang", "Back", .time),
        ("Battle Ropes", "Full Body", .time),
        // Chest
        ("Pec Deck (Machine)", "Chest", .weightReps),
        ("Cable Crossover", "Chest", .weightReps),
        ("Decline Bench Press (Barbell)", "Chest", .weightReps),
        ("Incline Bench Press (Smith Machine)", "Chest", .weightReps),
        ("Assisted Dip (Machine)", "Chest", .weightReps),
        // Back
        ("Assisted Pull Up (Machine)", "Back", .weightReps),
        ("Close Grip Lat Pulldown", "Back", .weightReps),
        ("Straight Arm Pulldown (Cable)", "Back", .weightReps),
        ("Single Arm Cable Row", "Back", .weightReps),
        ("Rack Pull", "Back", .weightReps),
        // Shoulders
        ("Arnold Press (Dumbbell)", "Shoulders", .weightReps),
        ("Front Raise (Dumbbell)", "Shoulders", .weightReps),
        ("Lateral Raise (Cable)", "Shoulders", .weightReps),
        ("Upright Row (Cable)", "Shoulders", .weightReps),
        ("Shrug (Dumbbell)", "Shoulders", .weightReps),
        // Arms
        ("Bicep Curl (Cable)", "Biceps", .weightReps),
        ("Bicep Curl (Machine)", "Biceps", .weightReps),
        ("Incline Curl (Dumbbell)", "Biceps", .weightReps),
        ("Concentration Curl", "Biceps", .weightReps),
        ("Triceps Extension (Machine)", "Triceps", .weightReps),
        ("Triceps Dip (Machine)", "Triceps", .weightReps),
        ("Triceps Kickback (Dumbbell)", "Triceps", .weightReps),
        ("Overhead Triceps Extension (Cable)", "Triceps", .weightReps),
        // Legs & glutes
        ("Goblet Squat", "Legs", .weightReps),
        ("Smith Machine Squat", "Legs", .weightReps),
        ("Pendulum Squat", "Legs", .weightReps),
        ("Lying Leg Curl (Machine)", "Legs", .weightReps),
        ("Seated Calf Raise", "Legs", .weightReps),
        ("Step Up (Dumbbell)", "Legs", .weightReps),
        ("Walking Lunge (Dumbbell)", "Legs", .weightReps),
        ("Sumo Deadlift", "Legs", .weightReps),
        ("Hip Adduction (Machine)", "Glutes", .weightReps),
        ("Cable Kickback", "Glutes", .weightReps),
        ("Cable Pull Through", "Glutes", .weightReps),
        ("Single Leg Hip Thrust", "Glutes", .weightReps),
        // Core & full body
        ("Russian Twist", "Core", .weightReps),
        ("Bicycle Crunch", "Core", .weightReps),
        ("Dead Bug", "Core", .weightReps),
        ("Pallof Press (Cable)", "Core", .weightReps),
        ("Lying Leg Raise", "Core", .weightReps),
        ("Burpee", "Full Body", .weightReps),
        ("Thruster (Dumbbell)", "Full Body", .weightReps),
        ("Farmer's Carry", "Full Body", .weightReps),
        ("Sled Push", "Full Body", .weightReps),
    ]

    /// Adds the v2 exercises, fixes tracking for existing ones (e.g. Plank → time),
    /// and puts the StairMaster finisher at the end of the plan's routines. Runs once.
    static func seedLibraryV2IfNeeded(_ context: ModelContext) {
        let key = "seededLibraryV2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        var exercisesByName: [String: Exercise] = [:]
        for exercise in (try? context.fetch(FetchDescriptor<Exercise>())) ?? [] {
            exercisesByName[exercise.name.lowercased()] = exercise
        }
        for (name, group, tracking) in libraryV2 {
            if let existing = exercisesByName[name.lowercased()] {
                existing.tracking = tracking
            } else {
                let exercise = Exercise(name: name, muscleGroup: group, tracking: tracking)
                context.insert(exercise)
                exercisesByName[name.lowercased()] = exercise
            }
        }

        if let stairMaster = exercisesByName["stairmaster"] {
            let planNames = Set(trainingPlan.map(\.name))
            for routine in (try? context.fetch(FetchDescriptor<Routine>())) ?? [] where planNames.contains(routine.name) {
                guard !routine.entries.contains(where: { $0.exercise == stairMaster }) else { continue }
                let entry = RoutineExercise(
                    order: (routine.entries.map(\.order).max() ?? -1) + 1,
                    targetSets: 1,
                    repTarget: "20 min"
                )
                context.insert(entry)
                entry.exercise = stairMaster
                routine.entries.append(entry)
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

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
