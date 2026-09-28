import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/vertical.dart';

/// Turning-point hysteresis on fused altitude.
void main() {
  VerticalAccumulator feed(Iterable<double> hs, {bool baro = true}) {
    final v = VerticalAccumulator(hasBarometer: baro);
    for (final h in hs) {
      v.update(h);
    }
    return v;
  }

  test('threshold follows the altitude source', () {
    expect(VerticalAccumulator(hasBarometer: true).threshold, TrackingConfig.verticalHysteresisBaroM);
    expect(VerticalAccumulator(hasBarometer: false).threshold, TrackingConfig.verticalHysteresisGpsM);
  });

  group('a reversal commits only once it exceeds the threshold', () {
    for (final (baro, rise, committed) in [(true, 9.9, false), (true, 10.0, true), (false, 24.9, false), (false, 25.0, true)]) {
      test('${baro ? 'baro' : 'gps'}: 100 m down, then $rise m up → descent counted $committed', () {
        final v = feed([1000, 950, 900, 900 + rise], baro: baro);
        expect(v.descentM, committed ? 100 : 0);
        expect(v.ascentM, 0);
      });
    }
  });

  test('noise inside the band is ignored', () {
    final v = feed([1000, 996, 1000, 995, 1001, 994, 1000]);
    expect(v.descentM, 0);
    expect(v.ascentM, 0);
  });

  test('full cycle: down, up, down', () {
    final v = feed([1000, 900, 910, 1100, 1090, 1050, 1060]);
    expect(v.descentM, closeTo(100 + 50, 1e-9));
    expect(v.ascentM, closeTo(200, 1e-9));
  });

  test('the committed extreme is the true turning point, not the trigger sample', () {
    // down to 800, small wobble that does not reach the threshold, further down to 700, then up
    final v = feed([1000, 800, 805, 700, 720]);
    expect(v.descentM, 300);
  });

  test('monotonic climb commits nothing until it reverses', () {
    final v = feed(List.generate(200, (i) => 1000.0 + i));
    expect(v.ascentM, 0);
    v.update(1199 - 10);
    expect(v.ascentM, 199);
    expect(v.descentM, 0);
  });

  test('gps threshold hides smaller dips a barometer would count', () {
    final dips = [1000.0, 985.0, 1000.0, 985.0, 1000.0];
    expect(feed(dips, baro: true).descentM, 30);
    expect(feed(dips, baro: false).descentM, 0);
  });
}
