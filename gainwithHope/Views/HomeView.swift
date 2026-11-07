import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("userName") private var userName = "Hope"
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate, order: .reverse)
    private var finishedWorkouts: [Workout]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(greeting), \(userName)")
                            .font(.title.bold())
                        Text("Ready to train?")
                            .foregroundStyle(.secondary)
                    }

                    ProgrammeCard(
                        title: cardTitle,
                        routine: featuredRoutine,
                        onStart: { beginWorkout(from: featuredRoutine, in: context) }
                    )

                    WeekStrip(workouts: finishedWorkouts, plannedCount: plannedCount)

                    VStack(spacing: 10) {
                        NavigationLink {
                            ExercisesView()
                        } label: {
                            HomeLink(title: "Exercises", subtitle: "Your exercise library and records", systemImage: "figure.strengthtraining.traditional")
                        }
                        NavigationLink {
                            HistoryView()
                        } label: {
                            HomeLink(title: "History", subtitle: lastWorkoutText, systemImage: "clock.arrow.circlepath")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var plannedCount: Int {
        routines.filter { (1...7).contains($0.weekday) }.count
    }

    private var todaysRoutine: Routine? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return routines.first { $0.weekday == weekday }
    }

    /// The next planned routine after today (wrapping round the week).
    private var nextRoutine: Routine? {
        let today = Calendar.current.component(.weekday, from: .now)
        return (1...7)
            .map { (today - 1 + $0) % 7 + 1 }
            .lazy
            .compactMap { day in routines.first { $0.weekday == day } }
            .first
    }

    private var featuredRoutine: Routine? {
        todaysRoutine ?? nextRoutine
    }

    private var cardTitle: String {
        if todaysRoutine != nil { return "Today" }
        if let next = nextRoutine, let day = next.weekdayLabel { return "Rest day · next up \(day.capitalized)" }
        return "Quick start"
    }

    private var lastWorkoutText: String {
        guard let last = finishedWorkouts.first else { return "Past workouts and progress" }
        return "Last: \(last.name), \(last.startDate.formatted(.relative(presentation: .named)))"
    }
}

/// Starts a workout and opens the watch app. Shared by Home and Workouts.
func beginWorkout(from routine: Routine?, in context: ModelContext) {
    let workout = context.startWorkout(from: routine)
    WatchBridge.shared.workoutStarted(workout)
}

private struct ProgrammeCard: View {
    let title: String
    let routine: Routine?
    var onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(routine?.name ?? "Empty Workout")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 56, height: 56)
                    .background(.white, in: Circle())
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(routine?.name ?? "empty workout")")
    }

    private var subtitle: String {
        guard let routine else { return "Log whatever you're doing today" }
        let count = routine.entries.count
        return "\(count) exercises · " + routine.sortedEntries.prefix(3).compactMap { $0.exercise?.name }.joined(separator: ", ")
    }
}

/// Mon–Sun with a filled dot for each day you trained this week.
private struct WeekStrip: View {
    let workouts: [Workout]
    let plannedCount: Int

    var body: some View {
        let days = weekDays
        let trainedDays = Set(workouts.map { Calendar.current.startOfDay(for: $0.startDate) })
        let doneCount = days.filter { trainedDays.contains($0) }.count

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.headline)
                Spacer()
                Text(plannedCount > 0 ? "\(doneCount) / \(plannedCount) workouts" : "\(doneCount) workouts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                ForEach(days, id: \.self) { day in
                    let done = trainedDays.contains(day)
                    let isToday = Calendar.current.isDateInToday(day)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .strokeBorder(isToday ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 2)
                                .background(Circle().fill(done ? Color.accentColor : .clear))
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 32, height: 32)
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(isToday ? Color.accentColor : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))), \(done ? "trained" : "not trained")")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    /// Start of each day this week, Monday first.
    private var weekDays: [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

private struct HomeLink: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(Rectangle())
    }
}
