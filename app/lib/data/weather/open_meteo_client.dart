import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/core.dart';

/// One Open-Meteo call per elevation; never throws (null on any problem).
class OpenMeteoClient {
  OpenMeteoClient({http.Client? client, this.timeout = const Duration(seconds: 10)}) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;

  static const _base = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherSnapshot?> fetch(Resort r, {required int nowMs}) async {
    try {
      final base = await _get(r.lat, r.lon, r.baseAltM);
      if (base == null) return null;
      Map<String, Object?>? summit;
      if (r.summitAltM != null && r.summitAltM != r.baseAltM) summit = await _get(r.lat, r.lon, r.summitAltM);
      final cur = base['current'] as Map<String, Object?>?;
      final daily = base['daily'] as Map<String, Object?>?;
      final snowList = (daily?['snowfall_sum'] as List?)?.cast<num?>();
      return WeatherSnapshot(
        fetchedAt: nowMs,
        tempBaseC: (cur?['temperature_2m'] as num?)?.toDouble(),
        tempSummitC: ((summit?['current'] as Map<String, Object?>?)?['temperature_2m'] as num?)?.toDouble(),
        freshSnowCm: snowList == null || snowList.isEmpty ? null : snowList.first?.toDouble(),
        wmoCode: (cur?['weather_code'] as num?)?.toInt(),
        windKmh: (cur?['wind_speed_10m'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> _get(double lat, double lon, int? elevation) async {
    final q = {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current': 'temperature_2m,wind_speed_10m,weather_code',
      'daily': 'snowfall_sum',
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
