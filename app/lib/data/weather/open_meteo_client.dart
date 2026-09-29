import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/core.dart';
import 'weather_report.dart';

/// One Open-Meteo call per elevation; never throws (null on any problem).
///
/// Free fields used: `current` temperature / wind / weather code,
/// `daily.snowfall_sum` (cm, today) and `hourly.snow_depth` (metres, read at
/// the current hour) — all on the no-key forecast endpoint.
class OpenMeteoClient {
  OpenMeteoClient({http.Client? client, this.timeout = const Duration(seconds: 10)}) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;

  static const _base = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherReport?> fetch(Resort r, {required int nowMs}) async {
    try {
      final base = await _get(r.lat, r.lon, r.baseAltM);
      if (base == null) return null;
      Map<String, Object?>? summit;
      if (r.summitAltM != null && r.summitAltM != r.baseAltM) summit = await _get(r.lat, r.lon, r.summitAltM);
      return parse(base, summit: summit, nowMs: nowMs);
    } catch (_) {
      return null;
    }
  }

  /// Pure parser over the decoded JSON of the base call (+ optional summit call).
  static WeatherReport parse(Map<String, Object?> base, {Map<String, Object?>? summit, required int nowMs}) {
    final cur = base['current'] as Map<String, Object?>?;
    final daily = base['daily'] as Map<String, Object?>?;
    final snowList = (daily?['snowfall_sum'] as List?)?.cast<num?>();
    return WeatherReport(
      fetchedAt: nowMs,
      tempBaseC: (cur?['temperature_2m'] as num?)?.toDouble(),
      tempSummitC: ((summit?['current'] as Map<String, Object?>?)?['temperature_2m'] as num?)?.toDouble(),
      freshSnowCm: snowList == null || snowList.isEmpty ? null : snowList.first?.toDouble(),
      wmoCode: (cur?['weather_code'] as num?)?.toInt(),
      windKmh: (cur?['wind_speed_10m'] as num?)?.toDouble(),
      snowDepthCm: snowDepthCm(base['hourly'] as Map<String, Object?>?, currentTime: cur?['time'] as String?),
    );
  }

  /// `hourly.snow_depth` is in metres; picks the entry of the current hour
  /// (`current.time` = '2026-01-15T09:15' → 'T09'), else the first non-null.
  static double? snowDepthCm(Map<String, Object?>? hourly, {String? currentTime}) {
    final depths = (hourly?['snow_depth'] as List?)?.cast<num?>();
    if (depths == null || depths.isEmpty) return null;
    final times = (hourly?['time'] as List?)?.cast<String?>();
    num? pick;
    if (currentTime != null && times != null && currentTime.length >= 13) {
      final hourKey = currentTime.substring(0, 13);
      for (var i = 0; i < times.length && i < depths.length; i++) {
        if (times[i]?.startsWith(hourKey) == true && depths[i] != null) {
          pick = depths[i];
          break;
        }
      }
    }
    pick ??= depths.firstWhere((d) => d != null, orElse: () => null);
    return pick == null ? null : pick.toDouble() * 100;
  }

  Future<Map<String, Object?>?> _get(double lat, double lon, int? elevation) async {
    final q = {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current': 'temperature_2m,wind_speed_10m,weather_code',
      'daily': 'snowfall_sum',
      'hourly': 'snow_depth',
      'forecast_days': '1',
      'timezone': 'auto',
      if (elevation != null) 'elevation': '$elevation',
    };
    final uri = Uri.parse(_base).replace(queryParameters: q);
    final res = await _client.get(uri).timeout(timeout);
    if (res.statusCode != 200) return null;
    return (jsonDecode(res.body) as Map).cast<String, Object?>();
  }
}
