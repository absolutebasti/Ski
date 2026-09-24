import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:slopetrack/platform/location_source.dart';

void main() {
  test('Position maps to RawFix', () {
    final p = Position(
      latitude: 47.4, longitude: 12.3, timestamp: DateTime.fromMillisecondsSinceEpoch(1000), accuracy: 6,
      altitude: 1500, altitudeAccuracy: 9, heading: 180, headingAccuracy: 5, speed: 12.5, speedAccuracy: 0.4, isMocked: false,
    );
    final f = positionToRawFix(p);
    expect(f.ts, 1000);
    expect(f.lat, 47.4);
    expect(f.hAccM, 6);
    expect(f.gpsAltM, 1500);
    expect(f.vAccM, 9);
    expect(f.speedMs, 12.5);
    expect(f.speedAccMs, 0.4);
    expect(f.courseDeg, 180);
    expect(f.isMocked, isFalse);
  });
}
