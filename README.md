# gainwithHope 🏋️

A personal workout tracker for iPhone, in the spirit of Strong / Hevy, built just for me.

- **Start a workout** empty or from a saved routine (Push Day, Leg Day…)
- **Log as you go**: weight × reps per set, tick each set off, warm-up sets, add/remove sets and exercises
- **"Previous" column** shows what you did last time; new sets are pre-filled with it
- **Rest timer** starts automatically after each set, with a notification when the phone is locked
- **History** of every workout with duration, volume and sets
- **Exercise progress**: personal records and an estimated 1RM chart
- **Apple Watch**: starting a workout opens the watch app automatically, with live heart rate, calories, current exercise
  and a wrist tap when rest is over. It records a real workout session, so it **counts toward your Exercise ring**
- **Apple Health**: finished workouts are saved as *Traditional Strength Training* (by the watch if it's tracking, otherwise by the iPhone)
- kg or lb, all data stays on your phone (SwiftData)

Requires iOS 17+, watchOS 10+ and Xcode 16+.

## Put it on your iPhone (free, no paid developer account)

1. **Install Xcode** from the Mac App Store (it's big; give it a while). Open it once and let it install components.
2. **Sign in**: Xcode › Settings › Accounts › `+` › Apple ID, using your normal Apple ID.
3. **Get the code**:
   ```sh
   git clone https://github.com/future-stacks/gainwithHope.git
   open gainwithHope/gainwithHope.xcodeproj
   ```
4. **Signing**: click the blue `gainwithHope` project in the left sidebar › **Signing & Capabilities**, and set Team to
   *Your Name (Personal Team)* for **both** targets: `gainwithHope` and `gainwithHopeWatch`.
   If it complains the bundle identifier is taken: select the *project* (not a target) › Build Settings › search `APP_BUNDLE_ID`
   and change it to something unique like `com.yourname.gainwithHope`. Both apps pick it up from there.
5. **iPhone prep**: plug the iPhone into the Mac, tap *Trust*. On the iPhone, turn on
   Settings › Privacy & Security › **Developer Mode** (it restarts the phone).
6. **Run**: pick your iPhone in the device menu at the top of Xcode and press ▶︎ (⌘R).
7. First launch only: on the iPhone go to Settings › General › **VPN & Device Management** › your Apple ID › *Trust*. Then open the app.
8. In the app: **Settings tab › Connect Apple Health** and allow access.

### Apple Watch
Running the iPhone app from Xcode installs the watch app too (it's embedded). If it doesn't appear on the watch:
- On the watch, turn on Settings › Privacy & Security › **Developer Mode** (needed once, the watch restarts).
- Or open the **Watch** app on the iPhone › scroll to *Available Apps* › Install next to gainwithHope.
- Watch installs over the phone can be slow; keep the watch on its charger, near the phone, unlocked.

The first workout asks for Health access **on the watch**: allow heart rate and workouts.
You can turn the watch off any time in the iPhone app's Settings tab.

### The 7-day thing
Apps installed with a free Apple ID stop opening after **7 days**. Your workouts are **not** lost: just plug in the phone and press ▶︎ in Xcode again
(it updates in place and keeps your data). A paid Apple Developer account ($99/yr) makes it last a year.

## Project layout

```
gainwithHope/
  GainWithHopeApp.swift      app entry, SwiftData container
  Models/Models.swift        Exercise, Routine, Workout, WorkoutExercise, WorkoutSet
  Models/SeedData.swift      starter exercise library
  Services/HealthKitManager  saving workouts to Apple Health
  Services/RestTimer         rest countdown + notification
  Services/WatchBridge       iPhone side of the watch connection
gainwithHopeWatch/           watch app: workout session, heart rate, calories
Shared/WatchLink.swift       messages passed between iPhone and watch
  Views/                     screens (ActiveWorkoutView is the main logging screen)
```
