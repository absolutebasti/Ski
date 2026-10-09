import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

/// LIFT-QUALITY acceptance (docs/ENGINE.md): every lift type is counted as a
/// lift and contributes nothing to top speed, Ø ski speed, skied distance or
/// drop; skating, cat tracks and a stop on the slope never become lifts.
///
/// "Contributes nothing" is proved structurally: every one of those numbers is
/// a sum over RUN segments, so no RUN may cover the lift phase's time window
/// (beyond a few seconds of boundary snap at the station) and no run's top
/// speed may be stamped inside it. Where the lift is *faster* than the skier,
/// the day's top speed must also stay below the lift speed, live and final.

const _t0 = 1735288800000;

class _Replay {
  _Replay(this.phases, this.day, this.r, this.liveMax);
  final List<Phase> phases;
  final SyntheticDay day;
  final DayComputation r;
  /// Top speed on the live screen after every tick.
  final List<double> liveMax;
  /// Highest top speed the live screen ever showed during the day.
  double get liveMaxPeak => liveMax.fold(0, (m, v) => v > m ? v : m);
  /// Seconds the live screen showed a top speed above [v].
  int liveSecondsAbove(double v) => liveMax.where((x) => x > v).length;
  List<Segment> get runs => r.segments.where((s) => s.kind == SegmentKind.run).toList();
  String get describe =>
      r.segments.map((s) => '${s.kind.name}:${s.durationMs ~/ 1000}s/${(s.endAltM - s.startAltM).round()}m/${s.distanceM.round()}m').join(', ');
}

_Replay _replay(List<Phase> phases, {int seed = 5}) {
  final day = SyntheticDayGenerator(seed: seed, startTs: _t0).generate(phases);
  final e = TrackingEngine(dayId: 'lq');
  final fixes = day.fixes, press = day.pressures;
  var fi = 0, pi = 0;
  final liveMax = <double>[];
  for (var ts = press.first.ts; ts <= press.last.ts; ts += 1000) {
    while (fi < fixes.length && fixes[fi].ts <= ts) {
      e.addFix(fixes[fi++]);
    }
    while (pi < press.length && press[pi].ts <= ts) {
      e.addPressure(press[pi++]);
    }
    liveMax.add(e.tick(ts).live.stats.maxSpeedMs);
  }
  return _Replay(phases, day, e.finish(), liveMax);
}

/// What the engine can at best measure as skied distance: the GPS path (with
/// its noise) between consecutive fixes inside the RUN phases. At 3 m/s the
/// 4 m position noise more than doubles the path, so the noise-free truth is no
/// yardstick for slow runs.
double _fixPathInRuns(_Replay x) {
  var d = 0.0;
  final f = x.day.fixes;
  for (var i = 0; i < x.phases.length; i++) {
    if (x.phases[i].kind != SegmentKind.run) continue;
    final (ws, we) = _window(x.phases, i);
    for (var k = 1; k < f.length; k++) {
      if (f[k - 1].ts < ws || f[k].ts > we) continue;
      d += haversineM(f[k - 1].lat, f[k - 1].lon, f[k].lat, f[k].lon);
    }
  }
  return d;
}

/// [start, end] ms of phase [i] as the generator lays it out.
(int, int) _window(List<Phase> phases, int i) {
  var s = _t0;
  for (var k = 0; k < i; k++) {
    s += phases[k].durationS * 1000;
  }
  return (s, s + phases[i].durationS * 1000);
}

/// Seconds of phase [i] covered by RUN segments.
int _runCoverS(_Replay x, List<Phase> phases, int i) {
  final (ws, we) = _window(phases, i);
  var ms = 0;
  for (final s in x.runs) {
    final a = s.startTs > ws ? s.startTs : ws, b = s.endTs < we ? s.endTs : we;
    if (b > a) ms += b - a;
  }
  return ms ~/ 1000;
}

/// No run covers more than [slackS] of lift phase [i]; no top speed is stamped inside it.
void _expectLiftContributesNothing(_Replay x, List<Phase> phases, int i, {int slackS = 5}) {
  expect(_runCoverS(x, phases, i), lessThanOrEqualTo(slackS), reason: 'a run covers the lift phase: ${x.describe}');
  final (ws, we) = _window(phases, i);
  for (final s in x.runs) {
    final at = s.maxSpeedAtTs;
    if (at != null) expect(at < ws || at > we, isTrue, reason: 'run ${s.runNumber} top speed stamped inside the lift ride');
  }
}

/// Day stats agree with the run-only truth of the generator.
void _expectSkiNumbersFromRunsOnly(_Replay x) {
  final st = x.r.stats, d = x.day;
  // Confirmed max = 2 of 3 agreeing candidates on Doppler with 0.3 m/s noise.
  expect(st.maxSpeedMs, lessThanOrEqualTo(d.expectedMaxSpeedMs + 1.0), reason: x.describe);
  expect(st.dropM, closeTo(d.expectedDropM, d.expectedDropM * 0.06 + 5), reason: x.describe);
  // Skied distance = the GPS path of the run phases, give or take the few
  // boundary seconds; a lift would add hundreds of metres to thousands.
  final path = _fixPathInRuns(x);
  expect(st.skiDistanceM, closeTo(path, path * 0.12 + 40), reason: x.describe);
  final pathSpeed = path / d.expectedRunS;
  expect(st.avgSkiSpeedMs, closeTo(pathSpeed, pathSpeed * 0.2), reason: x.describe);
  expect(st.maxSpeedMs, lessThanOrEqualTo(x.runs.fold<double>(0, (m, s) => s.maxSpeedMs > m ? s.maxSpeedMs : m)));
}

void main() {
  // (name, lift phase, run phase after it). Runs are skied the real way
  // (Phase.realRun: speed swinging through the turns, heading changing); where
  // the lift is faster than the run, the top-speed assertion alone proves the
  // lift was kept out.
  final lifts = <(String, Phase, Phase)>[
    ('fixed chairlift 2.5 m/s constant', const Phase.cable(400, 480, avgSpeedMs: 2.5), Phase.realRun(400, 150, avgSpeedMs: 12)),
    ('detachable chair 5 m/s', const Phase.cable(500, 360, avgSpeedMs: 5), Phase.realRun(300, 200, avgSpeedMs: 3.2)),
    ('gondola 6 m/s', const Phase.cable(700, 420, avgSpeedMs: 6), Phase.realRun(300, 240, avgSpeedMs: 3.8)),
    ('gondola 7.5 m/s', const Phase.cable(800, 480, avgSpeedMs: 7.5), Phase.realRun(300, 240, avgSpeedMs: 4)),
    ('funicular 10 m/s', const Phase.cable(900, 300, avgSpeedMs: 10), Phase.realRun(300, 200, avgSpeedMs: 6)),
    ('3S / fast gondola 11 m/s', const Phase.cable(1000, 330, avgSpeedMs: 11), Phase.realRun(300, 200, avgSpeedMs: 6.5)),
    ('T-bar on skis 3 m/s, +200 m', const Phase.lift(200, 300, avgSpeedMs: 3, jitter: 0.1), Phase.realRun(200, 100, avgSpeedMs: 10)),
    ('platter 2 m/s, +180 m', const Phase.lift(180, 300, avgSpeedMs: 2, jitter: 0.1), Phase.realRun(200, 100, avgSpeedMs: 10)),
    ('gondola 6.5 m/s with a 5 min GPS dropout', const Phase.cable(900, 540, avgSpeedMs: 6.5, dropoutFrom: 120, dropoutTo: 420), Phase.realRun(300, 240, avgSpeedMs: 4)),
  ];

  group('every lift type is a lift and stays out of the ski numbers', () {
    for (final (name, lift, run) in lifts) {
      final phases = [const Phase.stop(60), lift, const Phase.stop(30), run, const Phase.stop(30)];
      test(name, () {
        for (final seed in [5, 21]) {
          final x = _replay(phases, seed: seed);
          expect(x.r.stats.liftCount, 1, reason: 'seed $seed: ${x.describe}');
          expect(x.r.stats.runCount, 1, reason: 'seed $seed: ${x.describe}');
          expect(x.r.stats.ascentM, closeTo(lift.altDeltaM, lift.altDeltaM * 0.1), reason: 'seed $seed: ${x.describe}');
          expect(x.r.stats.vehicleFlag, isFalse);
          _expectLiftContributesNothing(x, phases, 1);
          _expectSkiNumbersFromRunsOnly(x);
          expect(x.liveMax.last, closeTo(x.r.stats.maxSpeedMs, 0.01), reason: 'seed $seed: live == final');
          // Cabin clearly faster than the skier: the top speed alone shows
          // whether a single lift second leaked in (cabin jitter is 3 %).
          if (lift.avgSpeedMs > x.day.expectedMaxSpeedMs + 1.5) {
            expect(x.r.stats.maxSpeedMs, lessThan(lift.avgSpeedMs * 0.93), reason: 'seed $seed: top speed is the lift speed');
            expect(x.liveMaxPeak, lessThan(lift.avgSpeedMs * 0.93), reason: 'seed $seed: live top speed is the lift speed');
          }
        }
      });
    }
  });

  test('magic carpet 0.7 m/s: below the speed floor and the lift floors — never skiing, never a lift', () {
    // 0.7 m/s is under zeroClampMs / distanceMinSpeedMs (0.8) and a carpet
    // gains ~15 m (< liftMinGainM 30): the ride is a pause, by design.
    final phases = [const Phase.stop(30), const Phase.lift(15, 150, avgSpeedMs: 0.7, jitter: 0.05), const Phase.stop(20), Phase.realRun(60, 60, avgSpeedMs: 6), const Phase.stop(30)];
    final x = _replay(phases);
    expect(x.r.stats.liftCount, 0, reason: x.describe);
    expect(x.r.stats.runCount, 1, reason: x.describe);
    _expectLiftContributesNothing(x, phases, 1);
    _expectSkiNumbersFromRunsOnly(x);
  });

  group('a lift the skier joins without stopping', () {
    test('run straight onto a 10 m/s funicular: live and final top speed stay the run\'s', () {
      // Worst case for the live tracker: the segmenter is still in RUN when the
      // cabin accelerates, and the lift is only recognised retroactively.
      final phases = [const Phase.stop(30), Phase.realRun(200, 120, avgSpeedMs: 3), const Phase.cable(800, 360, avgSpeedMs: 10), const Phase.stop(30)];
      for (final seed in [5, 21]) {
        final x = _replay(phases, seed: seed);
        expect(x.r.stats.liftCount, 1, reason: 'seed $seed: ${x.describe}');
        expect(x.r.stats.runCount, 1, reason: 'seed $seed: ${x.describe}');
        _expectLiftContributesNothing(x, phases, 2, slackS: 8);
        expect(x.r.stats.maxSpeedMs, lessThan(6), reason: 'seed $seed: ${x.describe}');
        // Live, the ride is recognised only once the evidence window has
        // filled; until then the provisional run may show the cabin's speed.
        // It must be taken back, and within that recognition delay.
        expect(x.liveMax.last, lessThan(6), reason: 'seed $seed: the live screen kept a lift speed');
        expect(x.liveSecondsAbove(6), lessThanOrEqualTo(TrackingConfig.finalizeLookbackS), reason: 'seed $seed: lift speed shown too long');
      }
    });

    test('off a 7.5 m/s gondola straight into a slow run: the start snap keeps the cabin out of the run', () {
      final phases = [const Phase.stop(30), const Phase.cable(500, 360, avgSpeedMs: 7.5), Phase.realRun(300, 200, avgSpeedMs: 3.5), const Phase.stop(30)];
      for (final seed in [5, 21]) {
        final x = _replay(phases, seed: seed);
        expect(x.r.stats.liftCount, 1, reason: 'seed $seed: ${x.describe}');
        expect(x.r.stats.runCount, 1, reason: 'seed $seed: ${x.describe}');
        _expectLiftContributesNothing(x, phases, 1, slackS: 8);
        expect(x.r.stats.maxSpeedMs, lessThan(6.5), reason: 'seed $seed: ${x.describe}');
        expect(x.liveMaxPeak, lessThan(6.5), reason: 'seed $seed: the live screen showed the cabin speed');
      }
    });
  });

  group('false positives: no lift', () {
    test('skating on a slightly rising traverse (1–3 m/s, +0.3 m/s)', () {
      const phases = [Phase.stop(30), Phase.run(300, 150, avgSpeedMs: 12), Phase.other(36, 120, avgSpeedMs: 2, jitter: 0.5), Phase.run(300, 150, avgSpeedMs: 12), Phase.stop(30)];
      for (final seed in [5, 21]) {
        final x = _replay(phases, seed: seed);
        expect(x.r.stats.liftCount, 0, reason: 'seed $seed: ${x.describe}');
        expect(x.r.stats.runCount, inInclusiveRange(1, 2), reason: 'seed $seed: ${x.describe}');
        expect(x.r.stats.dropM, closeTo(600, 40));
      }
    });

    test('skating with a steady rhythm (2 m/s, low spread) on the same traverse', () {
      const phases = [Phase.stop(30), Phase.run(300, 150, avgSpeedMs: 12), Phase.other(36, 120, avgSpeedMs: 2, jitter: 0.1), Phase.run(300, 150, avgSpeedMs: 12), Phase.stop(30)];
      final x = _replay(phases);
      expect(x.r.stats.liftCount, 0, reason: x.describe);
    });

    test('slow cat track descent (4 m/s, −0.2 m/s) stays run/other', () {
      const phases = [Phase.stop(30), Phase.run(400, 200, avgSpeedMs: 12), Phase.other(-40, 200, avgSpeedMs: 4), Phase.run(300, 150, avgSpeedMs: 12), Phase.stop(30)];
      for (final seed in [5, 21]) {
        final x = _replay(phases, seed: seed);
        expect(x.r.stats.liftCount, 0, reason: 'seed $seed: ${x.describe}');
        expect(x.r.stats.runCount, inInclusiveRange(1, 2), reason: 'seed $seed: ${x.describe}');
        expect(x.r.segments.where((s) => s.kind == SegmentKind.lift), isEmpty);
      }
    });

    test('a steady skier on a straight piste (8 m/s ± 15 %, no speed wave) stays a run', () {
      // Speed spread alone is a weak cable test: a calm intermediate cruising
      // at 20–35 km/h has little of it, and 9 s slice centroids average the
      // turns out of the path. The run must survive anyway.
      for (final (v, drop) in [(5.0, 250.0), (8.0, 300.0)]) {
        final phases = [const Phase.stop(30), Phase.run(drop, 150, avgSpeedMs: v), const Phase.stop(30)];
        for (final seed in [5, 21]) {
          final x = _replay(phases, seed: seed);
          expect(x.r.stats.liftCount, 0, reason: '$v m/s, seed $seed: ${x.describe}');
          expect(x.r.stats.runCount, 1, reason: '$v m/s, seed $seed: ${x.describe}');
          expect(x.r.stats.dropM, closeTo(drop, drop * 0.08), reason: '$v m/s, seed $seed: ${x.describe}');
        }
      }
    });

    test('a 90 s stop on the slope stays a stop between two runs', () {
      const phases = [Phase.stop(30), Phase.run(300, 150, avgSpeedMs: 12), Phase.stop(90), Phase.run(300, 150, avgSpeedMs: 12), Phase.stop(30)];
      for (final seed in [5, 21]) {
        final x = _replay(phases, seed: seed);
        expect(x.r.stats.liftCount, 0, reason: 'seed $seed: ${x.describe}');
        expect(x.r.stats.runCount, 2, reason: 'seed $seed: ${x.describe}');
        final (ws, we) = _window(phases, 2);
        final pause = x.r.segments.where((s) => s.kind == SegmentKind.stop && s.startTs < we && s.endTs > ws).toList();
        expect(pause, isNotEmpty, reason: x.describe);
        expect(pause.first.durationMs, greaterThanOrEqualTo(60000), reason: x.describe);
        _expectSkiNumbersFromRunsOnly(x);
      }
    });
  });
}
