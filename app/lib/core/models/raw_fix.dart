/// One GPS fix as delivered by the platform (geolocator), untouched.
class RawFix {
  const RawFix({
    required this.ts,
    required this.lat,
    required this.lon,
    required this.hAccM,
    this.gpsAltM,
    this.vAccM,
    this.speedMs,
    this.speedAccMs,
    this.courseDeg,
    this.isMocked = false,
  });

  /// Epoch milliseconds.
  final int ts;
  final double lat;
  final double lon;
  final double hAccM;
  final double? gpsAltM;
  final double? vAccM;
  /// Doppler speed from the chipset; negative or null = invalid.
  final double? speedMs;
  final double? speedAccMs;
  final double? courseDeg;
  final bool isMocked;

  Map<String, Object?> toJson() => {
        'ts': ts, 'lat': lat, 'lon': lon, 'hAccM': hAccM, 'gpsAltM': gpsAltM, 'vAccM': vAccM,
        'speedMs': speedMs, 'speedAccMs': speedAccMs, 'courseDeg': courseDeg, 'isMocked': isMocked,
      };

  factory RawFix.fromJson(Map<String, Object?> j) => RawFix(
        ts: (j['ts'] as num).toInt(),
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        hAccM: (j['hAccM'] as num).toDouble(),
        gpsAltM: (j['gpsAltM'] as num?)?.toDouble(),
        vAccM: (j['vAccM'] as num?)?.toDouble(),
        speedMs: (j['speedMs'] as num?)?.toDouble(),
        speedAccMs: (j['speedAccMs'] as num?)?.toDouble(),
        courseDeg: (j['courseDeg'] as num?)?.toDouble(),
        isMocked: j['isMocked'] == true,
      );
}

/// One barometer sample.
class PressureSample {
  const PressureSample({required this.ts, required this.hPa});
  final int ts;
  final double hPa;

  Map<String, Object?> toJson() => {'ts': ts, 'hPa': hPa};
  factory PressureSample.fromJson(Map<String, Object?> j) =>
      PressureSample(ts: (j['ts'] as num).toInt(), hPa: (j['hPa'] as num).toDouble());
}
