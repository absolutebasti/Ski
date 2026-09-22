import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/features/map/track_geometry.dart';

import 'track_fixture.dart';

void main() {
  group('TrackGeometry.split', () {
    test('splits by state: lift, run, (stop hidden), run', () {
      final pts = fixtureTrack();
      final lines = TrackGeometry.split(pts, const []);
      expect(lines.map((l) => l.kind), [TrackLineKind.lift, TrackLineKind.run, TrackLineKind.run]);
      expect(lines[0].points.length, 60);
      expect(lines[1].points.length, 90);
      expect(lines[2].points.length, 40);
    });

    test('skips rejected points and points without a position', () {
      final pts = fixtureTrack();
      final withNoise = [
        ...pts.take(10),
        TrackPoint(ts: pts[10].ts, lat: 0, lon: 0, accepted: false, state: MotionState.run),
        TrackPoint(ts: pts[10].ts + 1, accepted: true, state: MotionState.run),
        ...pts.skip(11),
      ];
      final lines = TrackGeometry.split(withNoise, const []);
      expect(lines.expand((l) => l.points).any((p) => p.latitude == 0), isFalse);
      expect(lines.first.points.length, 59);
    });

    test('breaks a line on a time gap (signal loss is not bridged)', () {
      final pts = fixtureTrack();
      final shifted = [
        for (var i = 0; i < pts.length; i++)
          i < 100 ? pts[i] : TrackPoint(ts: pts[i].ts + 10 * 60 * 1000, lat: pts[i].lat, lon: pts[i].lon, accepted: true, state: pts[i].state),
      ];
      final lines = TrackGeometry.split(shifted, const []);
      expect(lines.map((l) => l.kind), [TrackLineKind.lift, TrackLineKind.run, TrackLineKind.run, TrackLineKind.run]);
    });

    test('falls back to segments when the point state is unknown', () {
      final pts = fixtureTrack();
      final unknown = pts.map((p) => p.copyWith(state: MotionState.unknown)).toList();
      final lines = TrackGeometry.split(unknown, fixtureSegments(pts));
      expect(lines.map((l) => l.kind), [TrackLineKind.lift, TrackLineKind.run, TrackLineKind.run]);
    });

    test('a single point never yields a line', () {
      expect(TrackGeometry.split(fixtureTrack().take(1).toList(), const []), isEmpty);
    });
  });

  group('TrackGeometry helpers', () {
    test('nearest picks the closest drawable point by ts', () {
      final pts = fixtureTrack();
      expect(TrackGeometry.nearest(pts, pts[42].ts + 400)!.ts, pts[42].ts);
      expect(TrackGeometry.nearest(pts, pts[42].ts + 600)!.ts, pts[43].ts);
      expect(TrackGeometry.nearest(pts, pts.first.ts - 99999)!.ts, pts.first.ts);
      expect(TrackGeometry.nearest(pts, pts.last.ts + 99999)!.ts, pts.last.ts);
      expect(TrackGeometry.nearest(const [], 0), isNull);
    });

    test('bounds and first/last cover the drawable points', () {
      final pts = fixtureTrack();
      final b = TrackGeometry.bounds(pts)!;
      expect(b.$1.latitude <= b.$2.latitude, isTrue);
      expect(b.$1.longitude <= b.$2.longitude, isTrue);
      expect(TrackGeometry.first(pts)!.latitude, closeTo(pts.first.lat!, 1e-9));
      expect(TrackGeometry.last(pts)!.latitude, closeTo(pts.last.lat!, 1e-9));
      expect(TrackGeometry.bounds(const []), isNull);
    });
  });
}
