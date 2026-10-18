import SwiftUI

struct SettingsView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @AppStorage("restSeconds") private var restSeconds = 90
    @AppStorage("autoRestTimer") private var autoRestTimer = true
    @AppStorage("saveToHealth") private var saveToHealth = true
    @AppStorage("useWatch") private var useWatch = true

    @State private var healthConnected = HealthKitManager.shared.canSaveWorkouts
    @State private var healthError: String?

    private let restOptions = [30, 45, 60, 90, 120, 150, 180, 240, 300]

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight", selection: $unit) {
                        ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Start after each set", isOn: $autoRestTimer)
                    Picker("Rest time", selection: $restSeconds) {
                        ForEach(restOptions, id: \.self) { Text(formatClock(TimeInterval($0))).tag($0) }
                    }
                } header: {
                    Text("Rest Timer")
                } footer: {
                    Text("Allow notifications to get a ping when rest is over while your phone is locked.")
                }

                Section {
                    Toggle("Save workouts to Apple Health", isOn: $saveToHealth)
                    if healthConnected {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await connectHealth() }
                        } label: {
                            Label("Connect Apple Health", systemImage: "heart")
                        }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Finished workouts are saved as Traditional Strength Training, so they appear in the Fitness app. If Health has your body weight, an estimated calorie burn is added too.")
                        if let healthError {
                            Text(healthError).foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Toggle("Track workouts on Apple Watch", isOn: $useWatch)
                } header: {
                    Text("Apple Watch")
                } footer: {
                    Text("Starting a workout opens gainwithHope on your watch, which records heart rate and calories and counts toward your Exercise ring. The watch saves the workout to Apple Health when you finish on your iPhone.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .onAppear { healthConnected = HealthKitManager.shared.canSaveWorkouts }
        }
    }

    private func connectHealth() async {
        do {
            try await HealthKitManager.shared.requestAuthorization()
            healthConnected = HealthKitManager.shared.canSaveWorkouts
            healthError = healthConnected ? nil : HealthKitError.notAuthorized.errorDescription
        } catch {
            healthError = error.localizedDescription
        }
    }
}
