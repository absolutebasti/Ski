import Combine
import Foundation
import SwiftUI

/// Glue between the phone bridge and the workout session.
///
/// The phone stays the single source of truth: a wrist tap only sends
/// `{cmd: "start"}` / `{cmd: "end"}`, and the UI flips when the phone confirms
/// with a new application context. The workout session follows the phone's
/// status, so heart rate is collected exactly while a ski day runs.
final class WatchModel: ObservableObject {
    @Published private(set) var live: WatchLive = .idle
    @Published private(set) var reachable = false
    @Published private(set) var heartRate: Int?
    /// "start" or "end" while we wait for the phone to confirm.
    @Published private(set) var pending: String?

    let session = WatchSessionManager()
    let workout = WorkoutManager()

    private var bag = Set<AnyCancellable>()

    /// The phone has ~15 s to confirm; after that the button becomes usable again.
    private let pendingTimeout: TimeInterval = 15

    init() {
        workout.onHeartRate = { [weak self] bpm in
            self?.heartRate = bpm
            self?.session.send(heartRate: bpm)
        }
        session.$live
            .receive(on: DispatchQueue.main)
            .sink { [weak self] next in self?.apply(next) }
            .store(in: &bag)
        session.$reachable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.reachable = value }
            .store(in: &bag)
        session.activate()
        workout.requestAuthorization()
    }

    private func apply(_ next: WatchLive) {
        let wasRecording = live.isRecording
        live = next
        if next.isRecording != wasRecording || pendingMatches(next) {
            pending = nil
        }
        if next.isRecording, !workout.running {
            workout.start()
        } else if !next.isRecording, workout.running {
            workout.end()
            heartRate = nil
        }
    }

    private func pendingMatches(_ next: WatchLive) -> Bool {
        (pending == "start" && next.isRecording) || (pending == "end" && !next.isRecording)
    }

    var isPending: Bool { pending != nil }

    func startDay() { send("start") }

    func endDay() { send("end") }

    private func send(_ command: String) {
        guard pending == nil else { return }
        pending = command
        session.send(command: command)
        // Never leave the button stuck if the phone stays silent.
        DispatchQueue.main.asyncAfter(deadline: .now() + pendingTimeout) { [weak self] in
            if self?.pending == command { self?.pending = nil }
        }
    }
}
