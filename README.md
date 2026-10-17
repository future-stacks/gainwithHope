# gainwithHope 🏋️

A personal workout tracker for iPhone, in the spirit of Strong / Hevy, built just for me.

- **Start a workout** empty or from a saved routine (Push Day, Leg Day…)
- **Log as you go**: weight × reps per set, tick each set off, warm-up sets, add/remove sets and exercises
- **"Previous" column** shows what you did last time; new sets are pre-filled with it
- **Rest timer** starts automatically after each set, with a notification when the phone is locked
- **History** of every workout with duration, volume and sets
- **Exercise progress**: personal records and an estimated 1RM chart
- **Apple Health**: finished workouts are saved as *Traditional Strength Training*, so they show up in the Fitness app
- kg or lb, all data stays on your phone (SwiftData)

Requires iOS 17+ and Xcode 16+.

## Put it on your iPhone (free, no paid developer account)

1. **Install Xcode** from the Mac App Store (it's big; give it a while). Open it once and let it install components.
2. **Sign in**: Xcode › Settings › Accounts › `+` › Apple ID, using your normal Apple ID.
3. **Get the code**:
   ```sh
   git clone https://github.com/future-stacks/gainwithHope.git
   open gainwithHope/gainwithHope.xcodeproj
   ```
4. **Signing**: click the blue `gainwithHope` project in the left sidebar › target `gainwithHope` › **Signing & Capabilities** › Team: pick *Your Name (Personal Team)*.
   If it complains the bundle identifier is taken, change `com.futurestacks.gainwithHope` to something unique like `com.yourname.gainwithHope`.
5. **iPhone prep**: plug the iPhone into the Mac, tap *Trust*. On the iPhone, turn on
   Settings › Privacy & Security › **Developer Mode** (it restarts the phone).
6. **Run**: pick your iPhone in the device menu at the top of Xcode and press ▶︎ (⌘R).
7. First launch only: on the iPhone go to Settings › General › **VPN & Device Management** › your Apple ID › *Trust*. Then open the app.
8. In the app: **Settings tab › Connect Apple Health** and allow access.

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
  Views/                     screens (ActiveWorkoutView is the main logging screen)
```
