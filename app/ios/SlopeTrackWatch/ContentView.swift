import SwiftUI

/// Black background, one metric per row, colour-coded like the phone's live
/// screen (graphite + champagne + ice). Numbers are the loudest thing on the
/// display; everything else is a small uppercase label.
struct ContentView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if model.live.isRecording {
                liveView
            } else {
                idleView
            }
        }
    }

    // MARK: idle

    private var idleView: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Button(action: { Haptics.start(); model.startDay() }) {
                Text(model.isPending ? S.starting : S.start)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchTheme.champagne)
            .foregroundStyle(Color.black)
            .disabled(model.isPending)

            Text(model.reachable ? S.waiting : S.noPhone)
                .font(.system(size: 12))
                .foregroundStyle(WatchTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }

    // MARK: recording

    private var liveView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                MetricRow(label: S.vertical, value: WatchFormat.metres(model.live.dropM), unit: "m", colour: WatchTheme.champagne)
                MetricRow(label: S.runs, value: "\(model.live.runCount)", unit: nil, colour: WatchTheme.textPrimary)
                MetricRow(label: S.topSpeed, value: WatchFormat.kmh(model.live.maxSpeedMs), unit: "km/h", colour: WatchTheme.ice)
                MetricRow(label: S.time, value: WatchFormat.duration(model.live.elapsedMs), unit: nil, colour: WatchTheme.textPrimary)
                MetricRow(
                    label: S.heartRate,
                    value: model.heartRate.map(String.init) ?? S.placeholder,
                    unit: model.heartRate == nil ? nil : "bpm",
                    colour: WatchTheme.danger
                )

                EndButton(pending: model.isPending, action: model.endDay)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }
}

/// Label above, big tabular number below — the phone's `StatTile` on a wrist.
private struct MetricRow: View {
    let label: String
    let value: String
    let unit: String?
    let colour: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(WatchTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(colour)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WatchTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Hold to end — same safeguard as the phone, so a glove never ends a ski day.
private struct EndButton: View {
    let pending: Bool
    let action: () -> Void
    @State private var holding = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WatchTheme.danger.opacity(holding ? 0.9 : 0.18))
            Text(pending ? S.ending : (holding ? S.end : S.holdToEnd))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(holding ? Color.black : WatchTheme.danger)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.2), value: holding)
        .onLongPressGesture(minimumDuration: 1.2, pressing: { isPressing in
            holding = isPressing
        }, perform: {
            holding = false
            guard !pending else { return }
            Haptics.end()
            action()
        })
        .disabled(pending)
    }
}

#Preview {
    ContentView().environmentObject(WatchModel())
}
