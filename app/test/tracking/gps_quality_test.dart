import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/gps_quality.dart';

/// Rolling 10 s median of hAcc → quality words.
void main() {
  test('none before the first fix and after reset', () {
    final q = GpsQualityTracker();
    expect(q.quality(0), GpsQuality.none);
    q.addAccepted(1000, 3);
    expect(q.quality(1000), GpsQuality.veryGood);
    q.reset();
    expect(q.quality(1000), GpsQuality.none);
  });

  group('median thresholds', () {
    for (final (hAcc, expected) in [
      (4.0, GpsQuality.veryGood), (5.0, GpsQuality.veryGood), (5.1, GpsQuality.good), (10.0, GpsQuality.good),
      (10.1, GpsQuality.ok), (20.0, GpsQuality.ok), (20.1, GpsQuality.weak), (29.0, GpsQuality.weak),
    ]) {
      test('median $hAcc m → $expected', () {
        final q = GpsQualityTracker();
        for (var i = 0; i < 3; i++) {
          q.addAccepted(i * 1000, hAcc);
        }
        expect(q.quality(2000), expected);
      });
    }
  });

  group('silence (gpsNoFixS = ${TrackingConfig.gpsNoFixS})', () {
    for (final (silenceMs, expected) in [(0, GpsQuality.veryGood), (9999, GpsQuality.veryGood), (10000, GpsQuality.veryGood), (10001, GpsQuality.none), (60000, GpsQuality.none)]) {
      test('$silenceMs ms after the last fix → $expected', () {
        final q = GpsQualityTracker()..addAccepted(5000, 3);
        expect(q.quality(5000 + silenceMs), expected);
      });
    }
  });

  test('the window forgets samples older than 10 s', () {
    final q = GpsQualityTracker();
    for (var i = 0; i < 3; i++) {
      q.addAccepted(i * 1000, 25); // weak
    }
    expect(q.quality(2000), GpsQuality.weak);
    for (var i = 11; i <= 13; i++) {
      q.addAccepted(i * 1000, 4);
    }
    expect(q.quality(13000), GpsQuality.veryGood, reason: 'the 25 m samples fell out of the window');
  });

  test('median is robust to a single outlier', () {
    final q = GpsQualityTracker();
    for (final (i, h) in [4.0, 4.0, 60.0, 4.0, 4.0].indexed) {
      q.addAccepted(i * 1000, h);
    }
    expect(q.quality(4000), GpsQuality.veryGood);
  });

  test('even window takes the upper median', () {
    final q = GpsQualityTracker()..addAccepted(0, 4)..addAccepted(1000, 30);
    expect(q.quality(1000), GpsQuality.weak);
  });

  test('quality degrades as accuracy worsens within the window', () {
    final q = GpsQualityTracker();
    final seen = <GpsQuality>[];
    for (var i = 0; i < 12; i++) {
      q.addAccepted(i * 1000, 3.0 + i * 3); // 3, 6, 9 … 36
      seen.add(q.quality(i * 1000));
    }
    expect(seen.first, GpsQuality.veryGood);
    expect(seen.last, GpsQuality.weak);
    expect(seen, contains(GpsQuality.good));
    expect(seen, contains(GpsQuality.ok));
  });
}
