import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/speed.dart';

/// SpeedEstimator (Doppler / distance fallback / median+EMA) and MaxSpeedTracker.
void main() {
  RawFix fix(int ts, {double lat = 47, double? speed, double speedAcc = 0.5}) =>
      RawFix(ts: ts, lat: lat, lon: 12, hAccM: 5, speedMs: speed, speedAccMs: speedAcc);

  group('SpeedEstimator', () {
    test('trusted Doppler passes through and settles the display value', () {
      final s = SpeedEstimator();
      for (var i = 0; i < 3; i++) {
        expect(s.update(fix(1000 * (i + 1), speed: 10), speedTrusted: true), 10);
      }
      expect(s.displaySpeed, 10);
    });

    group('zero clamp (zeroClampMs = ${TrackingConfig.zeroClampMs})', () {
      for (final (v, expected) in [(0.0, 0.0), (0.79, 0.0), (0.8, 0.8), (1.2, 1.2)]) {
        test('$v m/s → $expected', () => expect(SpeedEstimator().update(fix(1000, speed: v), speedTrusted: true), expected));
      }
    });

    test('untrusted: distance/time once the window spans 3 s, before that 0', () {
      final s = SpeedEstimator();
      final raw = <double>[];
      for (var i = 0; i <= 3; i++) {
        raw.add(s.update(fix(i * 1000, lat: 47 + i * 10 / 111320), speedTrusted: false)); // 10 m/s northwards
      }
      expect(raw.sublist(0, 3), [0, 0, 0]);
      expect(raw[3], closeTo(10, 0.1));
    });

    test('untrusted window keeps at most 5 s of positions', () {
      final s = SpeedEstimator();
      double? v;
      for (var i = 0; i <= 12; i++) {
        v = s.update(fix(i * 1000, lat: 47 + i * 10 / 111320), speedTrusted: false);
      }
      expect(v, closeTo(10, 0.1));
      expect(s.displaySpeed, closeTo(10, 0.5));
    });

    test('median of 3 swallows a single spike; two agreeing samples move the EMA', () {
      final s = SpeedEstimator();
      for (var i = 1; i <= 3; i++) {
        s.update(fix(i * 1000, speed: 10), speedTrusted: true);
      }
      expect(s.update(fix(4000, speed: 30), speedTrusted: true), 30, reason: 'raw value is returned');
      expect(s.displaySpeed, 10, reason: 'median [10,10,30] = 10');
      s.update(fix(5000, speed: 30), speedTrusted: true);
      expect(s.displaySpeed, closeTo(10 + TrackingConfig.displayEmaAlpha * 20, 1e-9));
    });

    test('a gap longer than windowResetGapS resets the estimator', () {
      final s = SpeedEstimator();
      s.update(fix(1000, speed: 4), speedTrusted: true);
      s.update(fix(2000, speed: 4), speedTrusted: true);
      expect(s.displaySpeed, 4);
      s.update(fix(2000 + TrackingConfig.windowResetGapS.toInt() * 1000 + 1, speed: 10), speedTrusted: true);
      expect(s.displaySpeed, 10, reason: 'fresh EMA, no blend with the old 4');
      s.reset();
      expect(s.displaySpeed, 0);
    });
  });

  group('MaxSpeedTracker', () {
    test('needs two of three candidates within 15 %', () {
      final m = MaxSpeedTracker();
      expect(m.offer(10, 1), isFalse);
      expect(m.max, 0);
      expect(m.offer(10.5, 2), isTrue);
      expect(m.max, 10.5);
      expect(m.maxTs, 2);
    });

    group('agreement tolerance', () {
      for (final (second, confirmed) in [(11.4, true), (11.7, true), (11.8, false), (13.0, false)]) {
        test('10 then $second → confirmed $confirmed', () {
          final m = MaxSpeedTracker()..offer(10, 1);
          expect(m.offer(second, 2), confirmed);
        });
      }
    });

    test('a lone spike is ignored, a later agreeing value confirms it', () {
      final m = MaxSpeedTracker()..offer(10, 1)..offer(10.5, 2);
      expect(m.offer(30, 3), isFalse);
      expect(m.max, 10.5);
      expect(m.offer(29, 4), isTrue, reason: 'two of the last three agree');
      expect(m.max, 29);
    });

    group('hard cap (hardSpeedCapMs = ${TrackingConfig.hardSpeedCapMs})', () {
      for (final (v, counted) in [(44.9, true), (45.0, true), (45.1, false), (80.0, false)]) {
        test('$v m/s counted $counted', () {
          final m = MaxSpeedTracker();
          m.offer(v, 1);
          expect(m.offer(v, 2), counted);
        });
      }
    });

    test('values at or below the current max never re-confirm', () {
      final m = MaxSpeedTracker()..offer(20, 1)..offer(20, 2);
      expect(m.offer(20, 3), isFalse);
      expect(m.offer(19, 4), isFalse);
      expect(m.maxTs, 2);
    });

    test('reset clears max and candidates', () {
      final m = MaxSpeedTracker()..offer(20, 1)..offer(20, 2);
      m.reset();
      expect(m.max, 0);
      expect(m.maxTs, isNull);
      expect(m.offer(10, 3), isFalse);
    });
  });
}
