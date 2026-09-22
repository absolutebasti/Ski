import Foundation
import WatchConnectivity

/// WatchConnectivity side of the bridge.
///
/// Phone → watch: application context `{status, dayId, dropM, runCount,
/// maxSpeedMs, elapsedMs, speedMs, altM}` (latest value wins, arrives even when
/// this app is in the background).
/// Watch → phone: `sendMessage` with `{cmd: "start"|"end"}` and `{hr: bpm}`.
/// `sendMessage` wakes the iPhone app in the background; when the phone is not
/// reachable the newest value is buffered and flushed on the next reachability
/// change — for heart rate only the latest sample matters.
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var live: WatchLive = .idle
    @Published private(set) var reachable = false
    @Published private(set) var activated = false

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private var pendingCommand: String?
    private var pendingHeartRate: Int?

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
        // Anything the phone sent while this app was not running.
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            apply(context)
        }
    }

    // MARK: watch → phone

    func send(command: String) {
        send(["cmd": command], keepAs: { self.pendingCommand = command })
    }

    func send(heartRate: Int) {
        send(["hr": heartRate], keepAs: { self.pendingHeartRate = heartRate })
    }

    private func send(_ message: [String: Any], keepAs keep: @escaping () -> Void) {
        guard let session, session.activationState == .activated, session.isReachable else {
            keep()
            return
        }
        session.sendMessage(message, replyHandler: nil) { _ in
            DispatchQueue.main.async { keep() }
        }
    }

    private func flushPending() {
        if let command = pendingCommand {
            pendingCommand = nil
            send(command: command)
        }
        if let bpm = pendingHeartRate {
            pendingHeartRate = nil
            send(heartRate: bpm)
        }
    }

    // MARK: phone → watch

    private func apply(_ context: [String: Any]) {
        let next = WatchLive(context: context)
        DispatchQueue.main.async { self.live = next }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.activated = activationState == .activated
            self.reachable = session.isReachable
            if self.activated {
                let context = session.receivedApplicationContext
                if !context.isEmpty { self.live = WatchLive(context: context) }
                self.flushPending()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.reachable = session.isReachable
            if session.isReachable { self.flushPending() }
        }
    }
}
