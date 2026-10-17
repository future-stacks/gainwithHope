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

    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else { return }
        for (name, group) in exercises {
            context.insert(Exercise(name: name, muscleGroup: group))
        }
        try? context.save()
    }
}
