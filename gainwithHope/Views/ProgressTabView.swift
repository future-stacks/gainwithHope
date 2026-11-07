import Charts
import SwiftData
import SwiftUI

/// Progress tab: weekly training overview and per-lift progress.
struct ProgressTabView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate)
    private var workouts: [Workout]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var section = ProgressSection.overview

    private enum ProgressSection: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case lifts = "Lifts"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Section", selection: $section) {
                        ForEach(ProgressSection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch section {
                    case .overview: overview
                    case .lifts: lifts
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
        }
    }

    // MARK: - Overview

    private var overview: some View {
        let weeks = weeklyTotals
        let thisWeek = weeks.last ?? WeekTotal(start: .now, workouts: 0, volumeKg: 0)

        return VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                StatTile(title: "This week", value: "\(thisWeek.workouts)", caption: "workouts")
                StatTile(title: "Volume", value: unit.formatTotal(thisWeek.volumeKg), caption: "this week")
                StatTile(title: "All time", value: "\(workouts.count)", caption: "workouts")
            }

            Card(title: "Workout Volume", subtitle: "Total weight lifted per week (\(unit.rawValue))") {
                Chart(weeks) { week in
                    BarMark(
                        x: .value("Week", week.start, unit: .weekOfYear),
                        y: .value("Volume", unit.fromKg(week.volumeKg))
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 200)
            }

            Card(title: "Workouts per Week", subtitle: "Last 8 weeks") {
                Chart(weeks) { week in
                    LineMark(
                        x: .value("Week", week.start, unit: .weekOfYear),
                        y: .value("Workouts", week.workouts)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Week", week.start, unit: .weekOfYear),
                        y: .value("Workouts", week.workouts)
                    )
                }
                .foregroundStyle(Color.accentColor)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 160)
            }
        }
    }

    /// The last 8 weeks (Monday start), oldest first, including empty weeks.
    private var weeklyTotals: [WeekTotal] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<8).reversed().compactMap { offset -> WeekTotal? in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let inWeek = workouts.filter { $0.startDate >= start && $0.startDate < end }
            return WeekTotal(start: start, workouts: inWeek.count, volumeKg: inWeek.reduce(0) { $0 + $1.totalVolumeKg })
        }
    }

    // MARK: - Lifts

    private var lifts: some View {
        let progress = liftProgress
        return VStack(spacing: 10) {
            if progress.isEmpty {
                ContentUnavailableView(
                    "No lifts yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Finish a workout and your lifts show up here.")
                )
            }
            ForEach(progress) { lift in
                NavigationLink {
                    ExerciseDetailView(exercise: lift.exercise)
                } label: {
                    LiftRow(lift: lift, unit: unit)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Weight exercises you've done, most recently trained first.
    private var liftProgress: [LiftProgress] {
        exercises
            .filter { $0.tracking == .weightReps }
            .compactMap { exercise -> LiftProgress? in
                let sessions = exercise.finishedEntries.compactMap { entry -> (Date, Double)? in
                    guard let date = entry.workout?.startDate else { return nil }
                    let best = entry.sets
                        .filter { $0.isCompleted && !$0.isWarmup }
                        .map(\.estimatedOneRepMaxKg)
                        .max() ?? 0
                    return best > 0 ? (date, best) : nil
                }
                // finishedEntries is newest first.
                guard let latest = sessions.first, let first = sessions.last else { return nil }
                return LiftProgress(
                    exercise: exercise,
                    lastDate: latest.0,
                    latestKg: latest.1,
                    bestKg: sessions.map { $0.1 }.max() ?? latest.1,
                    change: first.1 > 0 && sessions.count > 1 ? (latest.1 - first.1) / first.1 : nil,
                    history: sessions.reversed().map { $0.1 }
                )
            }
            .sorted { $0.lastDate > $1.lastDate }
    }
}

private struct WeekTotal: Identifiable {
    let start: Date
    let workouts: Int
    let volumeKg: Double
    var id: Date { start }
}

private struct LiftProgress: Identifiable {
    let exercise: Exercise
    let lastDate: Date
    let latestKg: Double
    let bestKg: Double
    /// Change in estimated 1RM from the first session to the latest, e.g. 0.14 = +14%.
    let change: Double?
    /// Best estimated 1RM per session, oldest first.
    let history: [Double]
    var id: PersistentIdentifier { exercise.persistentModelID }
}

private struct LiftRow: View {
    let lift: LiftProgress
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lift.exercise.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("Est. 1RM \(unit.format(lift.latestKg)) · best \(unit.format(lift.bestKg))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if lift.history.count > 1 {
                Chart {
                    ForEach(lift.history.indices, id: \.self) { index in
                        LineMark(x: .value("Session", index), y: .value("1RM", lift.history[index]))
                            .interpolationMethod(.monotone)
                    }
                }
                .foregroundStyle(Color.accentColor)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(width: 60, height: 28)
                .accessibilityHidden(true)
            }
            if let change = lift.change {
                Text(change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(change >= 0 ? Color.accentColor : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((change >= 0 ? Color.accentColor : .orange).opacity(0.15), in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(Rectangle())
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct Card<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
