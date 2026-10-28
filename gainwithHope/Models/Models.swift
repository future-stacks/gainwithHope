import Foundation
import SwiftData

// All weights are stored in kilograms and converted for display (see WeightUnit).

@Model
final class Exercise {
    var name: String
    var muscleGroup: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var workoutEntries: [WorkoutExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \RoutineExercise.exercise)
    var routineEntries: [RoutineExercise] = []

    init(name: String, muscleGroup: String) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.createdAt = .now
    }
}

@Model
final class Routine {
    var name: String
    var createdAt: Date
    /// Copied into the workout's notes when you start it (e.g. the cardio finisher).
    var notes: String = ""
    /// Calendar weekday this routine is planned for (1 = Sunday … 7 = Saturday), 0 = any day.
    var weekday: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var entries: [RoutineExercise] = []

    init(name: String) {
        self.name = name
        self.createdAt = .now
    }

    var sortedEntries: [RoutineExercise] {
        entries.sorted { $0.order < $1.order }
    }
}

@Model
final class RoutineExercise {
    var order: Int
    var targetSets: Int
    /// Free text like "8–10", "12–15 ea" or "45s".
    var repTarget: String = ""
    var exercise: Exercise?
    var routine: Routine?

    init(order: Int, targetSets: Int, repTarget: String = "") {
        self.order = order
        self.targetSets = targetSets
        self.repTarget = repTarget
    }
}

@Model
final class Workout {
    /// Stable id shared with the Apple Watch app.
    var uuid: UUID = UUID()
    var name: String
    var startDate: Date
    /// nil while the workout is in progress.
    var endDate: Date?
    var notes: String
    var savedToHealth: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []

    init(name: String, startDate: Date = .now) {
        self.name = name
        self.startDate = startDate
        self.endDate = nil
        self.notes = ""
        self.savedToHealth = false
    }

    var sortedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var duration: TimeInterval {
        (endDate ?? .now).timeIntervalSince(startDate)
    }

    var completedSets: [WorkoutSet] {
        exercises.flatMap(\.sets).filter(\.isCompleted)
    }

    var totalVolumeKg: Double {
        completedSets
            .filter { !$0.isWarmup }
            .reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }
}

@Model
final class WorkoutExercise {
    var order: Int
    /// Rep target from the routine, shown while logging.
    var repTarget: String = ""
    var exercise: Exercise?
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workoutExercise)
    var sets: [WorkoutSet] = []

    init(order: Int) {
        self.order = order
    }

    var sortedSets: [WorkoutSet] {
        sets.sorted { $0.order < $1.order }
    }

    var displayName: String {
        exercise?.name ?? "Deleted exercise"
    }
}

@Model
final class WorkoutSet {
    var order: Int
    var weightKg: Double
    var reps: Int
    var isCompleted: Bool
    var isWarmup: Bool
    var workoutExercise: WorkoutExercise?

    init(order: Int, weightKg: Double = 0, reps: Int = 0, isWarmup: Bool = false) {
        self.order = order
        self.weightKg = weightKg
        self.reps = reps
        self.isCompleted = false
        self.isWarmup = isWarmup
    }

    /// Epley estimated one-rep max.
    var estimatedOneRepMaxKg: Double {
        guard reps > 0 else { return 0 }
        return reps == 1 ? weightKg : weightKg * (1 + Double(reps) / 30)
    }
}

extension Exercise {
    /// The most recent finished session of this exercise, ignoring `workout` (usually the one in progress).
    func lastCompletedEntry(excluding workout: Workout? = nil) -> WorkoutExercise? {
        workoutEntries
            .filter { entry in
                guard let w = entry.workout, w.endDate != nil else { return false }
                return w.persistentModelID != workout?.persistentModelID
            }
            .max { ($0.workout?.startDate ?? .distantPast) < ($1.workout?.startDate ?? .distantPast) }
    }

    /// Finished sessions, newest first.
    var finishedEntries: [WorkoutExercise] {
        workoutEntries
            .filter { $0.workout?.endDate != nil }
            .sorted { ($0.workout?.startDate ?? .distantPast) > ($1.workout?.startDate ?? .distantPast) }
    }
}

// MARK: - Creating workouts

extension ModelContext {
    /// Adds an exercise to a workout, pre-filling sets with what you did last time.
    @discardableResult
    func addExercise(
        _ exercise: Exercise, to workout: Workout, order: Int, setCount: Int? = nil, repTarget: String = ""
    ) -> WorkoutExercise {
        let entry = WorkoutExercise(order: order)
        insert(entry)
        entry.exercise = exercise
        entry.repTarget = repTarget
        workout.exercises.append(entry)

        let previous = exercise.lastCompletedEntry(excluding: workout)?.sortedSets.filter(\.isCompleted) ?? []
        let count = setCount ?? (previous.isEmpty ? 3 : previous.count)
        for i in 0..<count {
            let template = previous.indices.contains(i) ? previous[i] : previous.last
            let set = WorkoutSet(
                order: i,
                weightKg: template?.weightKg ?? 0,
                reps: template?.reps ?? 0,
                isWarmup: previous.indices.contains(i) ? previous[i].isWarmup : false
            )
            insert(set)
            entry.sets.append(set)
        }
        return entry
    }

    @discardableResult
    func startWorkout(from routine: Routine?) -> Workout {
        let workout = Workout(name: routine?.name ?? Workout.defaultName())
        workout.notes = routine?.notes ?? ""
        insert(workout)
        for (i, entry) in (routine?.sortedEntries ?? []).enumerated() {
            if let exercise = entry.exercise {
                addExercise(exercise, to: workout, order: i, setCount: entry.targetSets, repTarget: entry.repTarget)
            }
        }
        try? save()
        return workout
    }

    /// Marks the workout finished and drops sets that were never ticked off.
    /// Returns false (and deletes the workout) if nothing was completed.
    func finishWorkout(_ workout: Workout, at endDate: Date) -> Bool {
        for entry in workout.exercises {
            if entry.sets.contains(where: \.isCompleted) {
                let unfinished = entry.sets.filter { !$0.isCompleted }
                entry.sets.removeAll { !$0.isCompleted }
                for set in unfinished { delete(set) }
            }
        }
        let emptyEntries = workout.exercises.filter { !$0.sets.contains(where: \.isCompleted) }
        workout.exercises.removeAll { entry in emptyEntries.contains(entry) }
        for entry in emptyEntries { delete(entry) }

        guard !workout.exercises.isEmpty else {
            delete(workout)
            try? save()
            return false
        }
        workout.endDate = endDate
        try? save()
        return true
    }
}

extension Routine {
    /// "MON", "TUE"… or nil when the routine isn't tied to a day.
    var weekdayLabel: String? {
        guard (1...7).contains(weekday) else { return nil }
        return Calendar.current.shortWeekdaySymbols[weekday - 1].uppercased()
    }
}

extension Workout {
    static func defaultName(for date: Date = .now) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "Morning Workout"
        case 12..<17: return "Afternoon Workout"
        case 17..<22: return "Evening Workout"
        default: return "Night Workout"
        }
    }
}
