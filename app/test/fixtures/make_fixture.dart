// Regenerates test/fixtures/synthetic-day-7.json.gz — a DiagnosticsBundle of a
// short synthetic day run through the live engine. Pure Dart:
//   dart run test/fixtures/make_fixture.dart        (from app/)
// Device bundles from Diagnose → "Diagnosepaket teilen" can be dropped into
// test/fixtures/ as they are and loaded with BundleFixture.load(...).
import 'dart:io';

import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/share/diagnostics_bundle.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

const _phases = [Phase.stop(30), Phase.lift(400, 240), Phase.stop(20), Phase.run(400, 180, avgSpeedMs: 14), Phase.stop(20)];

void main() {
  final day = SyntheticDayGenerator(seed: 7).generate(_phases);
  const dayId = 'fixture-synthetic-7';
  final e = TrackingEngine(dayId: dayId);
  var fi = 0, pi = 0;
  for (var ts = day.pressures.first.ts; ts <= day.pressures.last.ts; ts += 1000) {
    while (fi < day.fixes.length && day.fixes[fi].ts <= ts) {
      e.addFix(day.fixes[fi++]);
    }
    while (pi < day.pressures.length && day.pressures[pi].ts <= ts) {
      e.addPressure(day.pressures[pi++]);
    }
    e.tick(ts);
  }
  final r = e.finish();
  final rec = DayRecord(
    id: dayId,
    startedAt: day.pressures.first.ts,
    endedAt: day.pressures.last.ts,
    status: DayStatus.finished,
    stats: r.stats,
    resortId: 'kitzbuehel',
    resortName: 'Kitzbühel',
    lastFixAt: day.fixes.last.ts,
    engineVersion: TrackingConfig.engineVersion,
  );
  final json = DiagnosticsBundle.toJson(day: rec, segments: r.segments, points: r.points, device: 'synthetic (seed 7)');
  json['exportedAt'] = '2026-09-28T00:00:00.000Z';
  final out = File('test/fixtures/synthetic-day-7.json.gz')..writeAsBytesSync(DiagnosticsBundle.encode(json));
  stdout.writeln('${out.path}: ${r.points.length} points, ${r.segments.length} segments, runs ${r.stats.runCount}, lifts ${r.stats.liftCount}, drop ${r.stats.dropM.round()} m, ${out.lengthSync()} bytes');
}
