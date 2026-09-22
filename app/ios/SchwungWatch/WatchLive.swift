import Foundation

/// Mirror of `WatchLivePayload` in lib/platform/watch/watch_messages.dart.
/// Keep both sides in sync — the keys are the contract.
struct WatchLive: Equatable {
    var status: String = WatchLive.statusIdle
    var dayId: String?
    var dropM: Double = 0
    var runCount: Int = 0
    var maxSpeedMs: Double = 0
    var elapsedMs: Int = 0
    var speedMs: Double = 0
    var altM: Double?

    static let statusRecording = "recording"
    static let statusIdle = "idle"
    static let idle = WatchLive()

    var isRecording: Bool { status == WatchLive.statusRecording }

    init() {}

    init(context: [String: Any]) {
        status = context["status"] as? String ?? WatchLive.statusIdle
        dayId = context["dayId"] as? String
        dropM = WatchLive.double(context["dropM"])
        runCount = Int(WatchLive.double(context["runCount"]).rounded())
        maxSpeedMs = WatchLive.double(context["maxSpeedMs"])
        elapsedMs = Int(WatchLive.double(context["elapsedMs"]).rounded())
        speedMs = WatchLive.double(context["speedMs"])
        altM = context["altM"] as? Double ?? (context["altM"] as? NSNumber)?.doubleValue
    }

    private static func double(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let i = value as? Int { return Double(i) }
        return 0
    }
}

/// SI → wrist. The phone formats for its own screen; the watch repeats the
/// rules here because it must stay readable without the phone.
enum WatchFormat {
    /// m/s → "42 km/h"
    static func kmh(_ ms: Double) -> String {
        String(format: "%.0f", max(0, ms) * 3.6)
    }

    /// metres → "1 240 m" (thin space, tabular)
    static func metres(_ m: Double) -> String {
        let v = Int(max(0, m).rounded())
        return v >= 1000 ? "\(v / 1000)\u{2009}\(String(format: "%03d", v % 1000))" : "\(v)"
    }

    /// ms → "3:12" or "1:03:12"
    static func duration(_ ms: Int) -> String {
        let total = max(0, ms) / 1000
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
