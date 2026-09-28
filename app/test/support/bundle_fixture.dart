import 'dart:io';

import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/share/diagnostics_bundle.dart';
import 'package:slopetrack/tracking/tracking.dart';
import 'package:xml/xml.dart';

/// A DiagnosticsBundle (`slopetrack-diag-*.json.gz`, docs/PLAN.md §9) decoded
/// for tests: device days become engine fixtures. Load with
/// `BundleFixture.load('test/fixtures/<name>.json.gz')` (cwd = app/).
class BundleFixture {
  BundleFixture._(this.json) : points = [for (final p in json['points'] as List) TrackPoint.fromJson((p as Map).cast<String, Object?>())];

  factory BundleFixture.decode(List<int> gzipBytes) => BundleFixture._(DiagnosticsBundle.decode(gzipBytes));

  static BundleFixture load(String path) => BundleFixture.decode(File(path).readAsBytesSync());

  final Map<String, Object?> json;
  final List<TrackPoint> points;

  int get format => (json['format'] as num).toInt();
  int get engineVersion => (json['engineVersion'] as num).toInt();
  String get device => '${json['device']}';
  Map<String, Object?> get day => (json['day'] as Map).cast<String, Object?>();
  String get dayId => '${day['id']}';
  List<Map<String, Object?>> get segments => [for (final s in json['segments'] as List) (s as Map).cast<String, Object?>()];

  /// Stats as exported by the device (the app's engine at export time).
  StoredStats get storedStats {
    final s = (day['stats'] as Map).cast<String, Object?>();
    return StoredStats(
      runCount: (s['runCount'] as num?)?.toInt() ?? 0,
      liftCount: (s['liftCount'] as num?)?.toInt() ?? 0,
      dropM: (s['dropM'] as num?)?.toDouble() ?? 0,
      maxSpeedMs: (s['maxSpeedMs'] as num?)?.toDouble() ?? 0,
      skiDistanceM: (s['skiDistanceM'] as num?)?.toDouble() ?? 0,
      hasBarometer: s['hasBarometer'] == true,
    );
  }

  /// Raw GPS fixes as the platform delivered them (rejected ones included).
  List<RawFix> get fixes => [
        for (final p in points)
          if (p.hasPosition)
            RawFix(ts: p.ts, lat: p.lat!, lon: p.lon!, hAccM: p.hAccM ?? 99, gpsAltM: p.gpsAltM, vAccM: p.vAccM, speedMs: p.speedMs, speedAccMs: p.speedAccMs, courseDeg: p.courseDeg),
      ];

  List<PressureSample> get pressures => [
        for (final p in points)
          if (p.pressureHpa != null) PressureSample(ts: p.ts, hPa: p.pressureHpa!),
      ];

  /// Offline replay through the current engine (same path as Diagnose → Neu berechnen).
  DayComputation replay() => TrackingEngine.computeDay(dayId, points);

  /// Live replay: 1 Hz ticks with the wall clock at each point's second.
  DayComputation replayLive() {
    final e = TrackingEngine(dayId: dayId);
    final sorted = [...points]..sort((a, b) => a.ts.compareTo(b.ts));
    if (sorted.isEmpty) return e.finish();
    var i = 0;
    for (var ts = sorted.first.ts; ts <= sorted.last.ts; ts += 1000) {
      while (i < sorted.length && sorted[i].ts <= ts) {
        final p = sorted[i++];
        if (p.hasPosition) e.addFix(RawFix(ts: p.ts, lat: p.lat!, lon: p.lon!, hAccM: p.hAccM ?? 99, gpsAltM: p.gpsAltM, vAccM: p.vAccM, speedMs: p.speedMs, speedAccMs: p.speedAccMs, courseDeg: p.courseDeg));
        if (p.pressureHpa != null) e.addPressure(PressureSample(ts: p.ts, hPa: p.pressureHpa!));
        if (p.heartRateBpm != null) e.addHeartRate(p.heartRateBpm!);
      }
      e.tick(ts);
    }
    return e.finish();
  }
}

class StoredStats {
  const StoredStats({required this.runCount, required this.liftCount, required this.dropM, required this.maxSpeedMs, required this.skiDistanceM, required this.hasBarometer});
  final int runCount;
  final int liftCount;
  final double dropM;
  final double maxSpeedMs;
  final double skiDistanceM;
  final bool hasBarometer;
}

/// Minimal GPX 1.1 reader: every `<trkpt>` with a `<time>` becomes a [RawFix]
/// (`<ele>` → gpsAltM, `gpxtpx:speed` or any `speed` element → speedMs).
/// GPX carries no accuracies, so [hAccM], [vAccM] and [speedAccMs] are
/// assumed — good enough to replay a foreign track through the gate.
List<RawFix> readGpx(String xml, {double hAccM = 8, double vAccM = 10, double speedAccMs = 1.0}) {
  final doc = XmlDocument.parse(xml);
  final out = <RawFix>[];
  for (final pt in doc.findAllElements('trkpt')) {
    final lat = double.tryParse(pt.getAttribute('lat') ?? '');
    final lon = double.tryParse(pt.getAttribute('lon') ?? '');
    final time = pt.getElement('time')?.innerText.trim();
    if (lat == null || lon == null || time == null) continue;
    final ts = DateTime.tryParse(time)?.millisecondsSinceEpoch;
    if (ts == null) continue;
    final ele = double.tryParse(pt.getElement('ele')?.innerText.trim() ?? '');
    double? speed;
    for (final e in pt.descendantElements) {
      if (e.name.local == 'speed') {
        speed = double.tryParse(e.innerText.trim());
        break;
      }
    }
    out.add(RawFix(ts: ts, lat: lat, lon: lon, hAccM: hAccM, gpsAltM: ele, vAccM: ele == null ? null : vAccM, speedMs: speed, speedAccMs: speed == null ? null : speedAccMs));
  }
  out.sort((a, b) => a.ts.compareTo(b.ts));
  return out;
}

/// Replays GPX fixes (no barometer) through the live engine.
DayComputation replayGpx(List<RawFix> fixes, {String dayId = 'gpx'}) {
  final e = TrackingEngine(dayId: dayId);
  if (fixes.isEmpty) return e.finish();
  var i = 0;
  for (var ts = fixes.first.ts; ts <= fixes.last.ts; ts += 1000) {
    while (i < fixes.length && fixes[i].ts <= ts) {
      e.addFix(fixes[i++]);
    }
    e.tick(ts);
  }
  return e.finish();
}
