import 'package:flutter_test/flutter_test.dart';
import 'package:schwung/core/core.dart';
import 'package:schwung/features/share/diagnostics_bundle.dart';

import 'synthetic_detail.dart';

void main() {
  test('diagnostics bundle round-trips through gzip JSON', () {
    final detail = syntheticDetail();
    final raw = syntheticRawPoints();
    final json = DiagnosticsBundle.toJson(day: detail.day, segments: detail.segments, points: raw, device: 'test-os 1.0');
    final bytes = DiagnosticsBundle.encode(json);
    expect(bytes.length, lessThan(raw.length * 200), reason: 'gzip should compress the point list');
    expect(bytes.take(2), [0x1f, 0x8b]);

    final back = DiagnosticsBundle.decode(bytes);
    expect(back['engineVersion'], TrackingConfig.engineVersion);
    expect(back['device'], 'test-os 1.0');
    final day = back['day'] as Map<String, Object?>;
    expect(day['id'], detail.day.id);
    expect(day['resortName'], 'Kitzbühel');
    expect((day['stats'] as Map)['runCount'], detail.day.stats.runCount);
    expect((back['segments'] as List).length, detail.segments.length);
    expect(((back['segments'] as List).first as Map)['kind'], detail.segments.first.kind.name);
    final points = (back['points'] as List).cast<Map<String, Object?>>();
    expect(points.length, raw.length);
    expect(points.any((p) => p['accepted'] == false), isTrue, reason: 'raw bundle keeps rejected fixes');
    final p0 = TrackPoint.fromJson(points.first);
    expect(p0.ts, raw.first.ts);
    expect(p0.lat, raw.first.lat);
    expect(p0.rejectReason, raw.first.rejectReason);
  });

  test('file name uses six id characters', () {
    expect(DiagnosticsBundle.fileName('0192abcd-1111-7000-8000-000000000001'), 'schwung-diag-0192ab.json.gz');
  });
}
