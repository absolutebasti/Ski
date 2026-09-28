import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/share/diagnostics_bundle.dart';

import '../support/bundle_fixture.dart';

/// The committed sample bundle decodes into TrackPoints and replays through
/// the engine; the GPX reader turns a foreign track into RawFixes.
void main() {
  group('synthetic-day-7.json.gz', () {
    final f = BundleFixture.load('test/fixtures/synthetic-day-7.json.gz');

    test('header and day metadata', () {
      expect(f.format, DiagnosticsBundle.formatVersion);
      expect(f.engineVersion, TrackingConfig.engineVersion);
      expect(f.dayId, 'fixture-synthetic-7');
      expect(f.day['resortId'], 'kitzbuehel');
      expect(f.device, contains('synthetic'));
      expect(f.segments.length, 3);
    });

    test('points decode with raw and derived fields', () {
      expect(f.points.length, 490);
      expect(f.points.first.ts, lessThan(f.points.last.ts));
      expect(f.points.where((p) => p.hasPosition).length, greaterThan(400));
      expect(f.points.every((p) => p.pressureHpa != null), isTrue, reason: 'barometer day');
      expect(f.points.where((p) => p.accepted).length, greaterThan(400));
      expect(f.points.map((p) => p.state).toSet(), containsAll([MotionState.run, MotionState.lift]));
      expect(f.fixes.length, f.points.where((p) => p.hasPosition).length);
      expect(f.pressures.length, f.points.length);
    });

    test('offline replay reproduces the stored stats', () {
      final stored = f.storedStats;
      final r = f.replay();
      expect(stored.runCount, 1);
      expect(stored.liftCount, 1);
      expect(r.stats.runCount, stored.runCount);
      expect(r.stats.liftCount, stored.liftCount);
      expect(r.stats.dropM, closeTo(stored.dropM, 0.01));
      expect(r.stats.maxSpeedMs, closeTo(stored.maxSpeedMs, 0.01));
      expect(r.stats.hasBarometer, stored.hasBarometer);
      expect(r.segments.map((s) => s.kind).toList(), f.segments.map((s) => SegmentKindX.fromDb('${s['kind']}')).toList());
    });

    test('live replay == offline replay', () {
      final live = f.replayLive();
      final off = f.replay();
      expect(live.segments.length, off.segments.length);
      for (var i = 0; i < live.segments.length; i++) {
        expect(live.segments[i].startTs, off.segments[i].startTs);
        expect(live.segments[i].endTs, off.segments[i].endTs);
      }
      expect(live.stats.dropM, closeTo(off.stats.dropM, 0.01));
    });

    test('decode() round-trips encode()', () {
      final again = BundleFixture.decode(DiagnosticsBundle.encode(f.json));
      expect(again.points.length, f.points.length);
      expect(again.dayId, f.dayId);
    });
  });

  group('readGpx', () {
    test('sample.gpx: trkpt with time → RawFix, ele and speed picked up', () {
      final fixes = readGpx(sampleGpx());
      expect(fixes.length, 4, reason: 'the point without <time> is skipped');
      expect(fixes.first.ts, DateTime.utc(2026, 1, 15, 9).millisecondsSinceEpoch);
      expect(fixes.first.lat, 47.4491);
      expect(fixes.first.gpsAltM, 1650);
      expect(fixes.first.speedMs, 12.5);
      expect(fixes.first.speedAccMs, 1.0);
      expect(fixes.first.hAccM, 8);
      expect(fixes[2].speedMs, isNull);
      expect(fixes[3].gpsAltM, isNull);
      expect(fixes[3].vAccM, isNull);
    });

    test('accuracy assumptions are configurable', () {
      final fixes = readGpx(sampleGpx(), hAccM: 3, vAccM: 4, speedAccMs: 0.2);
      expect(fixes.first.hAccM, 3);
      expect(fixes.first.vAccM, 4);
      expect(fixes.first.speedAccMs, 0.2);
    });

    test('fixes are sorted by time and replay through the engine', () {
      final fixes = readGpx(sampleGpx());
      for (var i = 1; i < fixes.length; i++) {
        expect(fixes[i].ts, greaterThan(fixes[i - 1].ts));
      }
      final r = replayGpx(fixes);
      expect(r.points.length, 4);
      expect(r.stats.acceptedFixes, 4);
      expect(r.stats.hasBarometer, isFalse);
    });

    test('an empty track yields nothing', () {
      expect(readGpx('<gpx version="1.1" creator="x"><trk><trkseg/></trk></gpx>'), isEmpty);
    });
  });
}

String sampleGpx() => io.File('test/fixtures/sample.gpx').readAsStringSync();
