import SwiftUI

struct WatchRootView: View {
    private let manager = WorkoutManager.shared

    var body: some View {
        if manager.isRunning {
            TabView {
                MetricsView()
                ControlsView()
            }
            .tabViewStyle(.verticalPage)
        } else {
            IdleView()
        }
    }
}

private struct IdleView: View {
    private let manager = WorkoutManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                if let phone = manager.phoneState, phone.phase == .active {
                    Text(phone.name)
                        .font(.headline)
                    Text("In progress on your iPhone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Track on Watch") { manager.start() }
                        .tint(.orange)
                } else {
                    Text("Start a workout on your iPhone and it will show up here.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Start Strength Workout") { manager.start() }
                        .tint(.orange)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct MetricsView: View {
    private let manager = WorkoutManager.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(formatElapsed(manager.elapsedTime(at: context.date)))
                    .font(.system(.title, design: .rounded).monospacedDigit().weight(.semibold))
                    .foregroundStyle(.yellow)

                Label("\(Int(manager.heartRate.rounded())) BPM", systemImage: "heart.fill")
                    .foregroundStyle(.pink)
                Label("\(Int(manager.activeEnergy.rounded())) kcal", systemImage: "flame.fill")
                    .foregroundStyle(.orange)

                if let phone = manager.phoneState, phone.phase == .active {
                    if let rest = phone.restEndDate, rest > context.date {
                        Label("Rest \(formatElapsed(rest.timeIntervalSince(context.date).rounded(.up)))", systemImage: "timer")
                            .foregroundStyle(.blue)
                    } else if let exercise = phone.currentExercise {
                        Text(exercise)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(2)
                        if let progress = phone.setProgress {
                            Text(progress)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.system(.body, design: .rounded).monospacedDigit())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

private struct ControlsView: View {
    private let manager = WorkoutManager.shared

    var body: some View {
        VStack(spacing: 12) {
            Button {
                manager.togglePause()
            } label: {
                Label(manager.isPaused ? "Resume" : "Pause", systemImage: manager.isPaused ? "play.fill" : "pause.fill")
            }
            .tint(.yellow)

            Button {
                manager.end()
            } label: {
                Label("End", systemImage: "xmark")
            }
            .tint(.red)

            Text("Finishing on your iPhone ends this automatically.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}
