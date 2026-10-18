import HealthKit
import SwiftUI
import WatchKit

@main
struct GainWithHopeWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        PhoneLink.shared.activate()
    }

    /// Called when the iPhone app starts a workout (HKHealthStore.startWatchApp).
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        PhoneLink.shared.activate()
        WorkoutManager.shared.start()
    }
}
