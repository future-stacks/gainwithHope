import Foundation
import WatchConnectivity

/// Watch side of the iPhone connection.
final class PhoneLink: NSObject, WCSessionDelegate {
    static let shared = PhoneLink()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Queued and delivered even if the iPhone app isn't running right now.
    func sendReliably(_ status: WatchStatus) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(WatchLink.encode(status))
    }

    /// Only sent if the iPhone app is open; fine to drop (e.g. live heart rate).
    func sendLive(_ status: WatchStatus) {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(WatchLink.encode(status), replyHandler: nil)
    }

    private func handle(_ dictionary: [String: Any]) {
        guard let state = WatchLink.decode(PhoneWorkoutState.self, from: dictionary) else { return }
        DispatchQueue.main.async {
            // Messages and application context can both arrive for the same update; ignore older ones.
            if let current = WorkoutManager.shared.phoneState, current.id == state.id, current.sentAt > state.sentAt {
                return
            }
            WorkoutManager.shared.apply(state)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        handle(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }
}
