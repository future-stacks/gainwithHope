import SwiftUI

struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        if let end = timer.endDate {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let remaining = max(0, end.timeIntervalSince(context.date))
                VStack(spacing: 10) {
                    ProgressView(value: timer.duration > 0 ? remaining / timer.duration : 0)
                        .tint(.blue)
                    HStack {
                        Button("−15s") { timer.add(-15) }
                            .buttonStyle(.bordered)
                        Spacer()
                        VStack(spacing: 0) {
                            Text("Rest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatClock(remaining.rounded(.up)))
                                .font(.title.bold().monospacedDigit())
                        }
                        Spacer()
                        Button("+15s") { timer.add(15) }
                            .buttonStyle(.bordered)
                        Button("Skip") { timer.stop() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(.regularMaterial)
            }
        }
    }
}
