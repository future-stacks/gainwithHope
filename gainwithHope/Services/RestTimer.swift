import Foundation
import Observation
import UIKit
import UserNotifications

/// Countdown between sets. Also schedules a local notification so you get pinged
/// when the phone is locked or the app is in the background.
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var duration: TimeInterval = 0

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let notificationID = "rest-timer"

    var isRunning: Bool { endDate != nil }

    func start(seconds: Int) {
        requestNotificationPermissionOnce()
        duration = TimeInterval(seconds)
        endDate = Date().addingTimeInterval(duration)
        schedule()
    }

    func add(_ seconds: Int) {
        guard let end = endDate else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(seconds))
        guard newEnd > Date() else { stop(); return }
        endDate = newEnd
        duration = max(1, duration + TimeInterval(seconds))
        schedule()
    }

    func stop() {
        task?.cancel()
        task = nil
        endDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    private func schedule() {
        task?.cancel()
        guard let end = endDate else { return }
        let interval = max(1, end.timeIntervalSinceNow)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        let content = UNMutableNotificationContent()
        content.title = "Rest is over"
        content.body = "Time for your next set 💪"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))

        task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.endDate = nil
        }
    }

    private func requestNotificationPermissionOnce() {
        let key = "askedNotificationPermission"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
