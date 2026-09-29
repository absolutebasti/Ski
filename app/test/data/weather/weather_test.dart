import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/weather/open_meteo_client.dart';
import 'package:slopetrack/data/weather/weather_report.dart';
import 'package:slopetrack/data/weather/wmo.dart';
import 'package:slopetrack/features/weather/weather_line.dart';

const resort = Resort(id: 'kitz', name: 'Kitzbühel', country: 'AT', lat: 47.4467, lon: 12.3923, radiusKm: 12, baseAltM: 800, summitAltM: 2000);

/// The shape the free forecast endpoint returns for
/// `current=temperature_2m,wind_speed_10m,weather_code&daily=snowfall_sum&hourly=snow_depth&forecast_days=1`.
Map<String, Object?> fixture({required double temp}) => {
      'current': {'time': '2026-01-15T09:15', 'temperature_2m': temp, 'wind_speed_10m': 12.0, 'weather_code': 71},
      'daily': {'time': ['2026-01-15'], 'snowfall_sum': [12.4]},
      'hourly': {
        'time': [for (var h = 0; h < 24; h++) '2026-01-15T${h.toString().padLeft(2, '0')}:00'],
        // metres; 09:00 carries 0.85 so the hour match is observable
        'snow_depth': [for (var h = 0; h < 24; h++) h == 9 ? 0.85 : 0.80],
      },
    };

void main() {
  test('parses base + summit, snowfall and snow_depth and formats the line', () async {
    final client = MockClient((req) async {
      expect(req.url.queryParameters['hourly'], 'snow_depth');
      expect(req.url.queryParameters['daily'], 'snowfall_sum');
      final elev = req.url.queryParameters['elevation'];
      return http.Response(jsonEncode(fixture(temp: elev == '2000' ? -6.5 : -1.2)), 200);
    });
    final w = await OpenMeteoClient(client: client).fetch(resort, nowMs: 1);
    expect(w, isNotNull);
    expect(w!.tempBaseC, -1.2);
    expect(w.tempSummitC, -6.5);
    expect(w.freshSnowCm, 12.4);
    expect(w.snowDepthCm, closeTo(85, 0.001), reason: 'metres → cm at the current hour');
    expect(w.hasSnowData, isTrue);
    expect(wmoBucket(w.wmoCode), WeatherBucket.snow);
    expect(WeatherLine.format(resort, w, de: true), 'Kitzbühel · −7° Berg · 12 cm Neuschnee');
    expect(WeatherLine.format(resort, w, de: true, includeResort: false), '−7° Berg · 12 cm Neuschnee');
    expect(WeatherLine.format(resort, null, de: true), 'Kitzbühel');
  });

  test('parse reads the fixture without a network; missing hourly → no depth', () {
    final w = OpenMeteoClient.parse(fixture(temp: -1.2), nowMs: 7);
    expect(w.fetchedAt, 7);
    expect(w.freshSnowCm, 12.4);
    expect(w.snowDepthCm, closeTo(85, 0.001));
    final bare = OpenMeteoClient.parse({'current': {'temperature_2m': 3.0, 'weather_code': 0}}, nowMs: 7);
    expect(bare.snowDepthCm, isNull);
    expect(bare.freshSnowCm, isNull);
    expect(bare.hasSnowData, isFalse);
  });

  test('snowDepthCm falls back to the first non-null hour without a time match', () {
    expect(OpenMeteoClient.snowDepthCm({'snow_depth': [null, 0.4, 0.5]}), closeTo(40, 0.001));
    expect(OpenMeteoClient.snowDepthCm({'snow_depth': [null, null]}), isNull);
    expect(OpenMeteoClient.snowDepthCm(null), isNull);
  });

  test('WeatherReport round-trips through JSON and wraps a plain snapshot', () {
    const r = WeatherReport(fetchedAt: 5, tempBaseC: -1, freshSnowCm: 3, snowDepthCm: 42, wmoCode: 2);
    final back = WeatherReport.fromJson(r.toJson());
    expect(back.snowDepthCm, 42);
    expect(back.freshSnowCm, 3);
    // Older JSON without the field still decodes.
    expect(WeatherReport.fromJson(const WeatherSnapshot(fetchedAt: 5, tempBaseC: 1).toJson()).snowDepthCm, isNull);
    final wrapped = WeatherReport.from(const WeatherSnapshot(fetchedAt: 5, tempBaseC: 1, wmoCode: 0));
    expect(wrapped.tempC, 1);
    expect(wrapped.hasSnowData, isFalse);
  });

  test('errors and non-200 become null', () async {
    final bad = MockClient((_) async => http.Response('nope', 500));
    expect(await OpenMeteoClient(client: bad).fetch(resort, nowMs: 1), isNull);
    final boom = MockClient((_) async => throw Exception('offline'));
    expect(await OpenMeteoClient(client: boom).fetch(resort, nowMs: 1), isNull);
  });

  test('wmo buckets', () {
    expect(wmoBucket(0), WeatherBucket.clear);
    expect(wmoBucket(2), WeatherBucket.partlyCloudy);
    expect(wmoBucket(45), WeatherBucket.fog);
    expect(wmoBucket(61), WeatherBucket.rain);
    expect(wmoBucket(75), WeatherBucket.snow);
    expect(wmoBucket(95), WeatherBucket.thunder);
  });
}
