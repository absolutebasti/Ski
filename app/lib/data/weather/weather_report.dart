import '../../core/core.dart';

/// [WeatherSnapshot] plus the snow depth Open-Meteo delivers for free
/// (`hourly=snow_depth`, metres → cm). Lives here until the lead promotes
/// `snowDepthCm` into core's WeatherSnapshot; every consumer that only knows
/// the base class keeps working, the conditions strip downcasts.
class WeatherReport extends WeatherSnapshot {
  const WeatherReport({
    required super.fetchedAt,
    super.tempBaseC,
    super.tempSummitC,
    super.freshSnowCm,
    super.wmoCode,
    super.windKmh,
    this.snowDepthCm,
  });

  /// Snow depth at the base station in centimetres; null when Open-Meteo has none.
  final double? snowDepthCm;

  /// Fresh snow (≥ 1 cm) or a snow depth (≥ 1 cm) is known.
  bool get hasSnowData => (freshSnowCm ?? 0) >= 1 || (snowDepthCm ?? 0) >= 1;

  /// Summit temperature when known, base otherwise.
  double? get tempC => tempSummitC ?? tempBaseC;

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'snowDepthCm': snowDepthCm};

  factory WeatherReport.fromJson(Map<String, Object?> j) {
    final base = WeatherSnapshot.fromJson(j);
    return WeatherReport.from(base, snowDepthCm: (j['snowDepthCm'] as num?)?.toDouble());
  }

  factory WeatherReport.from(WeatherSnapshot s, {double? snowDepthCm}) => s is WeatherReport && snowDepthCm == null
      ? s
      : WeatherReport(
          fetchedAt: s.fetchedAt,
          tempBaseC: s.tempBaseC,
          tempSummitC: s.tempSummitC,
          freshSnowCm: s.freshSnowCm,
          wmoCode: s.wmoCode,
          windKmh: s.windKmh,
          snowDepthCm: snowDepthCm ?? (s is WeatherReport ? s.snowDepthCm : null),
        );
}
