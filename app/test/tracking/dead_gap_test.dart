import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

/// A gap with nothing recorded at all (app not running, phone off) must never
/// stretch the open run or lift over it — launch audit 2026-10-09: a Start
/// 3.5 h after End produced one 212-minute "run".
void main() {
  List<TrackPoint> points(SyntheticDay d) => [
        for (final f in d.fixes)
          TrackPoint(
            ts: f.ts, lat: f.lat, lon: f.lon, hAccM: f.hAccM, gpsAltM: f.gpsAltM, vAccM: f.vAccM,
            speedMs: f.speedMs, speedAccMs: f.speedAccMs, accepted: true,
            pressureHpa: d.pressures.firstWhere((p) => p.ts == f.ts).hPa,
          ),
      ];

  const morning = [Phase.stop(30), Phase.lift(300, 300), Phase.run(300, 150), Phase.stop(30)];
  const gapMs = 3 * 3600 * 1000;

  DayComputation dayWithGap({required bool samePlace}) {
    final am = SyntheticDayGenerator(seed: 7).generate(morning);
    final last = am.fixes.last;
    final pm = SyntheticDayGenerator(
      seed: 8,
      startTs: last.ts + gapMs,
      lat0: samePlace ? last.lat : last.lat + 0.05, // ~5.5 km north
      lon0: last.lon,
      baseAltM: last.gpsAltM ?? 800,
    ).generate(const [Phase.stop(60)]);
    return TrackingEngine.computeDay('d', [...points(am), ...points(pm)]);
  }

  int longest(DayComputation r, SegmentKind k) =>
      r.segments.where((s) => s.kind == k).fold(0, (m, s) => s.durationMs > m ? s.durationMs : m);

  test('back at the same spot: the gap is a pause, the run keeps its length', () {
    final r = dayWithGap(samePlace: true);
    expect(longest(r, SegmentKind.run), lessThan(10 * 60000));
    expect(longest(r, SegmentKind.stop), greaterThan(gapMs - 5 * 60000));
    expect(r.stats.skiMs, lessThan(10 * 60000));
  });

  test('somewhere else: the gap is signal loss', () {
    final r = dayWithGap(samePlace: false);
    expect(longest(r, SegmentKind.run), lessThan(10 * 60000));
    expect(r.stats.signalLossMs, greaterThan(gapMs - 5 * 60000));
  });
}
