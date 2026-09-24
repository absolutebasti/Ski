# Apple Watch companion (WP-13)

Status: **sources complete, Xcode target not committed.** The watchOS platform
is not installed on the build Mac, and with an embedded watch app *every*
`flutter build ios` fails until it is (`This scheme builds an embedded Apple
Watch app. watchOS 26.2 must be installed`). The target was built, verified with
`xcodebuild -list`, then reverted so the first TestFlight build stays green.
Adding it is one command (step 2) once the platform is downloaded.

The Flutter side ships now and is inert without a watch: `WatchBridge` silently
swallows `MissingPluginException` / `PlatformException`.

## What the watch does

* Start / End the ski day from the wrist — the wrist only sends a command, the
  phone stays the single source of truth and confirms via the application context.
* Live rows: Höhenmeter · Abfahrten · Top-Speed · Zeit · Herzfrequenz.
* `HKWorkoutSession(.downhillSkiing)` gives heart rate **and** the background
  execution that keeps the watch app alive for a whole ski day. Heart rate goes
  back to the phone, where the tracking engine stores it per track point.

## Wire format (keep both sides in sync)

| Direction | Payload | Code |
|---|---|---|
| phone → watch | application context `{status, dayId, dropM, runCount, maxSpeedMs, elapsedMs, speedMs, altM}`, at most every 2 s | `lib/platform/watch/watch_messages.dart` ↔ `ios/SlopeTrackWatch/WatchLive.swift` |
| watch → phone | message `{cmd: "start"}` / `{cmd: "end"}` | `watchCommandFrom` ↔ `WatchSessionManager.send(command:)` |
| watch → phone | message `{hr: <bpm>}` | `WatchHeartRateSource` ↔ `WorkoutManager` |

SI units on the wire, formatting happens on each side (`Fmt` on the phone,
`WatchFormat` on the watch). Values are plist-safe (`String` / `num` / `bool`),
null fields are omitted.

`watch_connectivity` 0.2.10 only bridges `didReceiveMessage` and
`didReceiveApplicationContext` — no `transferUserInfo`. `sendMessage` needs a
reachable phone (it does wake the iOS app in the background). When the phone is
unreachable the watch buffers the newest command / heart rate and flushes it on
the next reachability change.

## 1. Prerequisite — install the watchOS platform

```bash
xcodebuild -downloadPlatform watchOS      # or Xcode > Settings > Components
xcodebuild -showsdks | grep watch         # watchOS + watchsimulator must both appear
xcrun simctl list runtimes | grep watch   # a watchOS runtime must be installed
```

Without this, adding the target breaks the iPhone build too.

## 2. Add the target — scripted (preferred)

```bash
cd app
python3 ios/SlopeTrackWatch/tools/add_watch_target.py
xcodebuild -list -project ios/Runner.xcodeproj   # SlopeTrackWatch must be listed
flutter build ios --no-codesign                  # must stay green
```

The script is idempotent (it refuses if `SlopeTrackWatch` already appears) and
undone with `git checkout -- ios/Runner.xcodeproj/project.pbxproj`. It adds the
native target, its three build configurations, the sources / resources phases
and the *Embed Watch Content* copy phase on Runner, with exactly the settings
listed in step 3.

Note the simulator caveat: `flutter build ios --simulator` refuses a watch
companion without `-d <simulator id>`. Use `flutter build ios --no-codesign`
(device) or pass a device id.

## 3. Add the target — by hand in Xcode (fallback)

1. `open app/ios/Runner.xcworkspace` → File > New > Target… > watchOS > **App**.
   * Product name `SlopeTrackWatch`, Interface SwiftUI, Language Swift,
     **no** Notification Scene, **no** Complication, **no** tests.
   * "Watch App for Existing iOS App" → companion `Runner`.
   * Bundle identifier **`de.torchtechnology.slopetrack.watchkitapp`** (Apple
     requires the companion's id + `.watchkitapp`).
2. Delete the files Xcode generated in the new group (`ContentView.swift`,
   `SlopeTrackWatchApp.swift`, `Assets.xcassets`, `Info.plist`, `Preview Content`)
   — **Move to Trash** — then File > Add Files… and add the existing folder
   `app/ios/SlopeTrackWatch` *without* "Copy items if needed", target membership
   `SlopeTrackWatch` only.
3. Target `SlopeTrackWatch` > **Signing & Capabilities**
   * Team `5GDU97KSQU` (Torch Technology), Automatically manage signing.
   * `+ Capability` → **HealthKit** (leave "Clinical Health Records" off).
   * `+ Capability` → **Background Modes** → check **Workout processing**.
   * Entitlements file: `SlopeTrackWatch/SlopeTrackWatch.entitlements` (already in the
     repo; Xcode may point at a new file — repoint it to this one).
4. Target `SlopeTrackWatch` > **Build Settings**
   * `Info.plist File` = `SlopeTrackWatch/Info.plist`,
     `Generate Info.plist File` = **No**.
   * `watchOS Deployment Target` = **10.0**, `Targeted Device Families` = 4.
   * `Marketing Version` = `$(FLUTTER_BUILD_NAME)`,
     `Current Project Version` = `$(FLUTTER_BUILD_NUMBER)`, and set the
     configuration file of all three configurations to `Flutter/Generated.xcconfig`.
     App Store Connect rejects a watch app whose version differs from the phone
     app's — this keeps them in lockstep with `flutter build --build-number`.
   * Swift Language Version 5, `Skip Install` = Yes.
5. Target `Runner` > Build Phases: an **Embed Watch Content** phase with
   `SlopeTrackWatch.app`, destination `$(CONTENTS_FOLDER_PATH)/Watch`, plus
   `SlopeTrackWatch` in Target Dependencies. Xcode adds both automatically.
6. There must be **three** build configurations on the watch target — Flutter
   also builds `Profile`. Xcode only creates Debug/Release; duplicate Release
   into `Profile` (Project > Info > Configurations is project-wide, so the
   target inherits it — just check the watch target lists Profile too).
7. Build: `flutter build ios --no-codesign`, then run the `Runner` scheme on a
   paired iPhone + Watch.

## 4. Wire the Flutter side (lead, WP-12 / main.dart)

Two lines, after the `ProviderContainer` exists and before `runApp`:

```dart
import 'package:slopetrack/platform/watch/watch.dart';
...
container.read(watchBridgeProvider.notifier).attach();
```

and, in the container's `overrides:` list, so heart rate reaches the engine:

```dart
heartRateSourceProvider.overrideWith(
  (ref) => WatchHeartRateSource(ref.watch(watchTransportProvider)),
),
```

`attach()` does the rest: it follows `recordingControllerProvider` (pushes the
live context while a day runs, one idle context when it ends) and turns
`{cmd: 'start'|'end'}` from the wrist into `startDay()` / `endDay()`. No change
to WP-05 is needed. Set `watchBridgeProvider.notifier.onCommand` before
`attach()` if the app ever wants to handle the commands itself.

Without the watch target (or without a paired watch) this is inert: every
plugin call is swallowed, nothing is sent, nothing throws.

## 5. App Store Connect

* The watch app needs **no separate app record** — it ships inside the iOS app.
* Add the watchOS **App Icon** (1024) and at least one watch screenshot
  (410×502 for a 45 mm watch) to the App Store listing before review.
* Privacy: heart rate is read from HealthKit on the watch and stored in the ski
  day on the phone. It never leaves the device — `docs/PRIVACY.md` and the
  `PrivacyInfo.xcprivacy` "Health & Fitness" entry must say so before submitting
  the build with the watch app.

## 6. Device QA (in addition to docs/QA.md)

1. Start from the wrist with the phone in the pocket, screen locked → phone
   starts recording, watch flips to the live rows within ~2 s.
2. Heart rate appears within ~10 s and the Fitness app shows a running
   "Skifahren (alpin)" workout.
3. Chairlift test: 30 min with the wrist down → the watch app stays alive
   (workout-processing) and numbers keep updating.
4. End with the hold gesture → phone writes the day, watch returns to Start,
   workout is saved to Health.
5. Phone out of range (put the iPhone in a rucksack 30 m away): the watch keeps
   the last numbers, `iPhone nicht erreichbar` is shown, and the queued command
   fires when it is back.
