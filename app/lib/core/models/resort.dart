/// Bundled resort centre (assets/data/resorts.json).
class Resort {
  const Resort({
    required this.id,
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    required this.radiusKm,
    this.baseAltM,
    this.summitAltM,
  });

  final String id;
  final String name;
  /// ISO 3166-1 alpha-2.
  final String country;
  final double lat;
  final double lon;
  final double radiusKm;
  final int? baseAltM;
  final int? summitAltM;

  factory Resort.fromJson(Map<String, Object?> j) => Resort(
        id: j['id'] as String,
        name: j['name'] as String,
        country: j['country'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        radiusKm: (j['radiusKm'] as num).toDouble(),
        baseAltM: (j['baseAltM'] as num?)?.toInt(),
        summitAltM: (j['summitAltM'] as num?)?.toInt(),
      );

  Map<String, Object?> toJson() => {
        'id': id, 'name': name, 'country': country, 'lat': lat, 'lon': lon, 'radiusKm': radiusKm,
        'baseAltM': baseAltM, 'summitAltM': summitAltM,
      };
}

/// Weather one-liner input (WP-11 fills it from Open-Meteo).
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.fetchedAt,
    this.tempBaseC,
    this.tempSummitC,
    this.freshSnowCm,
    this.wmoCode,
    this.windKmh,
  });
  final int fetchedAt;
  final double? tempBaseC;
  final double? tempSummitC;
  final double? freshSnowCm;
  final int? wmoCode;
  final double? windKmh;

  Map<String, Object?> toJson() => {
        'fetchedAt': fetchedAt, 'tempBaseC': tempBaseC, 'tempSummitC': tempSummitC,
        'freshSnowCm': freshSnowCm, 'wmoCode': wmoCode, 'windKmh': windKmh,
      };
  factory WeatherSnapshot.fromJson(Map<String, Object?> j) => WeatherSnapshot(
        fetchedAt: (j['fetchedAt'] as num).toInt(),
        tempBaseC: (j['tempBaseC'] as num?)?.toDouble(),
        tempSummitC: (j['tempSummitC'] as num?)?.toDouble(),
        freshSnowCm: (j['freshSnowCm'] as num?)?.toDouble(),
        wmoCode: (j['wmoCode'] as num?)?.toInt(),
        windKmh: (j['windKmh'] as num?)?.toDouble(),
      );
}
