import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

/// Runs a seeded synthetic day through the engine (1 Hz live ticks) and wraps
/// the result as a finished [DayDetail], exactly like the repository would.
DayDetail syntheticDetail({String id = '0192abcd-0000-7000-8000-000000000001', int seed = 7, String? resortName = 'Kitzbühel'}) {
  final day = SyntheticDayGenerator(seed: seed).generate();
  final e = TrackingEngine(dayId: id);
  var fi = 0, pi = 0;
  final start = day.pressures.first.ts, end = day.pressures.last.ts;
  for (var ts = start; ts <= end; ts += 1000) {
    while (fi < day.fixes.length && day.fixes[fi].ts <= ts) {
      e.addFix(day.fixes[fi++]);
    }
    while (pi < day.pressures.length && day.pressures[pi].ts <= ts) {
      e.addPressure(day.pressures[pi++]);
    }
    e.tick(ts);
  }
  final c = e.finish();
  return DayDetail(
    day: DayRecord(
      id: id,
      startedAt: c.points.first.ts,
      endedAt: c.points.last.ts,
      status: DayStatus.finished,
      resortId: resortName == null ? null : 'kitzbuehel',
      resortName: resortName,
      lastFixAt: c.points.last.ts,
      stats: c.stats,
    ),
    segments: c.segments,
    points: c.points.where((p) => p.accepted).toList(),
  );
}

/// All engine points (rejected included), for the diagnostics bundle.
List<TrackPoint> syntheticRawPoints({String id = 'raw', int seed = 7}) {
  final day = SyntheticDayGenerator(seed: seed).generate();
  final stored = <TrackPoint>[];
  var pi = 0;
  for (final f in day.fixes) {
    while (pi < day.pressures.length && day.pressures[pi].ts < f.ts) {
      pi++;
    }
    final p = pi < day.pressures.length && day.pressures[pi].ts == f.ts ? day.pressures[pi].hPa : null;
    stored.add(TrackPoint(ts: f.ts, lat: f.lat, lon: f.lon, hAccM: f.hAccM, gpsAltM: f.gpsAltM, vAccM: f.vAccM, speedMs: f.speedMs, speedAccMs: f.speedAccMs, courseDeg: f.courseDeg, pressureHpa: p));
  }
  // three unusable fixes (accuracy far beyond the gate) so the bundle really
  // carries rejected points — that is what makes it worth a diagnosis
  for (final i in [stored.length ~/ 4, stored.length ~/ 2, stored.length * 3 ~/ 4]) {
    final src = stored[i];
    stored.add(TrackPoint(ts: src.ts + 500, lat: src.lat! + 0.01, lon: src.lon! + 0.01, hAccM: 250, gpsAltM: src.gpsAltM, speedMs: src.speedMs));
  }
  return TrackingEngine.computeDay(id, stored).points;
}
