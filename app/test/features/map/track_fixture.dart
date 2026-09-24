import 'package:slopetrack/core/core.dart';

/// Kitzbühel-ish synthetic track: lift up (NE), run down (SW), short stop, second run.
List<TrackPoint> fixtureTrack({int startTs = 1735288800000}) {
  final pts = <TrackPoint>[];
  var ts = startTs;
  var lat = 47.4491, lon = 12.3913, alt = 800.0;
  void add(MotionState state, {double dLat = 0, double dLon = 0, double dAlt = 0, double speed = 5, double course = 0}) {
    lat += dLat;
    lon += dLon;
    alt += dAlt;
    pts.add(TrackPoint(ts: ts, lat: lat, lon: lon, hAccM: 6, speedMs: speed, courseDeg: course, fusedAltM: alt, accepted: true, state: state));
    ts += 1000;
  }

  for (var i = 0; i < 60; i++) {
    add(MotionState.lift, dLat: 0.00012, dLon: 0.00012, dAlt: 8, speed: 5, course: 45);
  }
  for (var i = 0; i < 90; i++) {
    add(MotionState.run, dLat: -0.00009, dLon: -0.00007, dAlt: -5.3, speed: 14, course: 220);
  }
  for (var i = 0; i < 15; i++) {
    add(MotionState.stop, speed: 0);
  }
  for (var i = 0; i < 40; i++) {
    add(MotionState.run, dLat: -0.00006, dLon: 0.00003, dAlt: -3, speed: 10, course: 160);
  }
  return pts;
}

List<Segment> fixtureSegments(List<TrackPoint> pts, {String dayId = 'day-1'}) {
  Segment seg(int idx, SegmentKind k, int a, int b, {int? run}) => Segment(
        id: '$dayId-$idx', dayId: dayId, kind: k, idx: idx, startTs: pts[a].ts, endTs: pts[b].ts, runNumber: run,
        startAltM: pts[a].fusedAltM ?? 0, endAltM: pts[b].fusedAltM ?? 0);
  return [
    seg(0, SegmentKind.lift, 0, 59),
    seg(1, SegmentKind.run, 60, 149, run: 1),
    seg(2, SegmentKind.stop, 150, 164),
    seg(3, SegmentKind.run, 165, pts.length - 1, run: 2),
  ];
}

DayDetail fixtureDetail({String dayId = 'day-1'}) {
  final pts = fixtureTrack();
  return DayDetail(
    day: DayRecord(id: dayId, startedAt: pts.first.ts, endedAt: pts.last.ts, status: DayStatus.finished, stats: DayStats.empty, resortName: 'Kitzbühel'),
    segments: fixtureSegments(pts, dayId: dayId),
    points: pts,
  );
}
