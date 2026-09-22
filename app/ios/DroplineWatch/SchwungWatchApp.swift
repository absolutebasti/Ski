import SwiftUI

/// Dropline on the wrist (docs/PLAN.md §0 A2 / WP-13).
///
/// Single-target watchOS app (watchOS 10+, no WatchKit extension). It never
/// records GPS itself: the phone owns the ski day, the watch starts and ends it
/// and shows the live numbers, and it contributes heart rate from a
/// HKWorkoutSession so the phone can store bpm per track point.
@main
struct DroplineWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
