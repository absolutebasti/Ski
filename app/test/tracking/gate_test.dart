import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/gate.dart';

/// FixGate, one table per threshold in TrackingConfig.
void main() {
  RawFix fix({int ts = 1000, double lat = 47, double lon = 12, double hAcc = 5, double? alt = 1500, double? vAcc = 8, double? speed = 5, double? speedAcc = 0.5, bool mocked = false}) =>
      RawFix(ts: ts, lat: lat, lon: lon, hAccM: hAcc, gpsAltM: alt, vAccM: vAcc, speedMs: speed, speedAccMs: speedAcc, isMocked: mocked);

  group('horizontal accuracy (maxHorizontalAccuracyM = ${TrackingConfig.maxHorizontalAccuracyM})', () {
    for (final (hAcc, ok) in [(0.5, true), (29.9, true), (30.0, true), (30.1, false), (99.0, false)]) {
      test('hAcc $hAcc → accepted $ok', () {
        final r = FixGate().evaluate(fix(hAcc: hAcc), 1000);
        expect(r.accepted, ok);
        expect(r.reason, ok ? RejectReason.none : RejectReason.hAcc);
      });
    }
  });

  group('fix age (maxFixAgeS = ${TrackingConfig.maxFixAgeS})', () {
    for (final (ageMs, ok) in [(0, true), (4999, true), (5000, true), (5001, false), (60000, false)]) {
      test('$ageMs ms old → accepted $ok', () {
        final r = FixGate().evaluate(fix(ts: 10000), 10000 + ageMs);
        expect(r.accepted, ok);
        if (!ok) expect(r.reason, RejectReason.stale);
      });
    }
  });

  group('altitude range (${TrackingConfig.minAltitudeM}…${TrackingConfig.maxAltitudeM} m)', () {
    for (final (alt, ok) in [(-0.1, false), (0.0, true), (2000.0, true), (4500.0, true), (4500.1, false)]) {
      test('alt $alt → accepted $ok', () {
        final r = FixGate().evaluate(fix(alt: alt), 1000);
        expect(r.accepted, ok);
        if (!ok) expect(r.reason, RejectReason.altitudeRange);
      });
    }
    test('missing altitude is fine', () => expect(FixGate().evaluate(fix(alt: null), 1000).accepted, isTrue));
  });

  group('implied speed (maxImpliedSpeedMs = ${TrackingConfig.maxImpliedSpeedMs})', () {
    for (final (metres, ok) in [(10.0, true), (44.0, true), (46.0, false), (500.0, false)]) {
      test('$metres m in 1 s → accepted $ok', () {
        final g = FixGate();
        expect(g.evaluate(fix(ts: 1000), 1000).accepted, isTrue);
        final r = g.evaluate(fix(ts: 2000, lat: 47 + metres / 111320), 2000);
        expect(r.accepted, ok);
        if (!ok) expect(r.reason, RejectReason.impliedSpeed);
      });
    }
    test('a rejected jump keeps the previous fix as reference', () {
      final g = FixGate();
      g.evaluate(fix(ts: 1000), 1000);
      g.evaluate(fix(ts: 2000, lat: 47.01), 2000); // 1.1 km → rejected
      expect(g.lastAccepted!.ts, 1000);
      expect(g.evaluate(fix(ts: 3000, lat: 47 + 40 / 111320), 3000).accepted, isTrue, reason: '40 m in 2 s');
    });
  });

  group('acceleration (maxAccelMs2 = ${TrackingConfig.maxAccelMs2})', () {
    for (final (dv, ok) in [(7.9, true), (8.0, true), (8.1, false), (20.0, false)]) {
      test('Doppler jump of $dv m/s in 1 s → accepted $ok', () {
        final g = FixGate();
        g.evaluate(fix(ts: 1000, speed: 2), 1000);
        final r = g.evaluate(fix(ts: 2000, speed: 2 + dv, lat: 47 + 5 / 111320), 2000);
        expect(r.accepted, ok);
        if (!ok) expect(r.reason, RejectReason.accel);
      });
    }
    test('untrusted speeds never trigger the acceleration check', () {
      final g = FixGate();
      g.evaluate(fix(ts: 1000, speed: 2), 1000);
      expect(g.evaluate(fix(ts: 2000, speed: 40, speedAcc: 3), 2000).accepted, isTrue);
    });
    test('after more than distanceMaxDtS the check is skipped', () {
      final g = FixGate();
      g.evaluate(fix(ts: 1000, speed: 0), 1000);
      expect(g.evaluate(fix(ts: 7000, speed: 30, lat: 47 + 100 / 111320), 7000).accepted, isTrue);
    });
  });

  group('quality flags', () {
    for (final (speedAcc, trusted) in [(1.4, true), (1.5, true), (1.6, false), (null, false)]) {
      test('speedAcc $speedAcc → speedTrusted $trusted', () => expect(FixGate().evaluate(fix(speedAcc: speedAcc), 1000).speedTrusted, trusted));
    }
    test('negative Doppler speed is not trusted', () => expect(FixGate().evaluate(fix(speed: -1), 1000).speedTrusted, isFalse));
    for (final (hAcc, speedAcc, cand) in [(20.0, 1.0, true), (20.1, 1.0, false), (20.0, 1.1, false), (5.0, 0.3, true)]) {
      test('hAcc $hAcc, speedAcc $speedAcc → maxCandidate $cand', () => expect(FixGate().evaluate(fix(hAcc: hAcc, speedAcc: speedAcc), 1000).maxCandidate, cand));
    }
    for (final (vAcc, anchor) in [(15.0, true), (15.1, false), (null, false)]) {
      test('vAcc $vAcc → altAnchor $anchor', () => expect(FixGate().evaluate(fix(vAcc: vAcc), 1000).altAnchor, anchor));
    }
  });

  group('order and mocking', () {
    test('same or earlier timestamp is non-monotonic', () {
      final g = FixGate();
      g.evaluate(fix(ts: 5000), 5000);
      expect(g.evaluate(fix(ts: 5000), 5000).reason, RejectReason.nonMonotonic);
      expect(g.evaluate(fix(ts: 4000), 5000).reason, RejectReason.nonMonotonic);
      expect(g.evaluate(fix(ts: 5001), 5001).accepted, isTrue);
    });
    test('mocked fixes are rejected before anything else', () {
      final r = FixGate().evaluate(fix(mocked: true, hAcc: 99), 1000);
      expect(r.reason, RejectReason.mocked);
    });
    test('reset forgets the last fix', () {
      final g = FixGate();
      g.evaluate(fix(ts: 5000), 5000);
      g.reset();
      expect(g.lastAccepted, isNull);
      expect(g.evaluate(fix(ts: 1000), 1000).accepted, isTrue);
    });
  });
}
