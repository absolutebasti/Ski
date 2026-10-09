import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

/// Feeds a synthetic day through the live engine at 1 Hz (wall clock = tick ts).
DayComputation runLiveDay(SyntheticDay day, {String dayId = 'cable'}) {
  final e = TrackingEngine(dayId: dayId);
  final fixes = day.fixes, press = day.pressures;
  var fi = 0, pi = 0;
  final start = press.isNotEmpty ? press.first.ts : fixes.first.ts;
  final end = press.isNotEmpty ? press.last.ts : fixes.last.ts;
  for (var ts = start; ts <= end; ts += 1000) {
    while (fi < fixes.length && fixes[fi].ts <= ts) {
      e.addFix(fixes[fi++]);
    }
    while (pi < press.length && press[pi].ts <= ts) {
      e.addPressure(press[pi++]);
    }
    e.tick(ts);
  }
  return e.finish();
}

/// Generates and replays one profile in a single call.
DayComputation day(List<Phase> phases, {int seed = 21, String dayId = 'cable', bool withBarometer = true}) =>
    runLiveDay(SyntheticDayGenerator(seed: seed, withBarometer: withBarometer).generate(phases), dayId: dayId);

/// `kind:duration/altitude-delta` per segment — the reason string for failures.
String describe(List<Segment> segments) =>
    segments.map((s) => '${s.kind.name}:${s.durationMs ~/ 1000}s/${(s.endAltM - s.startAltM).round()}m/${s.distanceM.round()}m').join(', ');

/// The largest confirmed max speed over the RUN segments of a day.
double maxOverRuns(List<Segment> segments) {
  var m = 0.0;
  for (final s in segments) {
    if (s.kind == SegmentKind.run && s.maxSpeedMs > m) m = s.maxSpeedMs;
  }
  return m;
}

/// The timestamp the [SyntheticDayGenerator] default start uses.
const t0 = 1735288800000;

/// `[start, end]` ms of phase [i] as the generator lays it out.
(int, int) phaseWindow(List<Phase> phases, int i, {int startTs = t0}) {
  var s = startTs;
  for (var k = 0; k < i; k++) {
    s += phases[k].durationS * 1000;
  }
  return (s, s + phases[i].durationS * 1000);
}

/// The best the engine could measure as skied distance: the GPS path (noise and
/// all) between consecutive fixes inside the phases of [kind].
///
/// At 2 m/s the 4 m position noise more than doubles the path, so the noise-free
/// truth of the generator is no yardstick for a slow run.
double fixPathInPhases(SyntheticDay day, List<Phase> phases, {SegmentKind kind = SegmentKind.run, int startTs = t0}) {
  var d = 0.0;
  final f = day.fixes;
  for (var i = 0; i < phases.length; i++) {
    if (phases[i].kind != kind) continue;
    final (ws, we) = phaseWindow(phases, i, startTs: startTs);
    for (var k = 1; k < f.length; k++) {
      if (f[k - 1].ts < ws || f[k].ts > we) continue;
      d += haversineM(f[k - 1].lat, f[k - 1].lon, f[k].lat, f[k].lon);
    }
  }
  return d;
}

/// Whether a gondola riding *down* is reclassified as a LIFT
/// ([TrackingConfig.descentRidesEnabled], **false** in the shipped build).
///
/// Every test that asserts something about a valley ride branches on this, so
/// flipping the constant flips the expectations together with the code instead of
/// leaving a suite that silently no longer means anything. A getter, not the
/// constant itself, so the analyser does not fold the branches away.
bool get descentRides => TrackingConfig.descentRidesEnabled;
