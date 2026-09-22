import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/data/weather/open_meteo_client.dart';
import 'package:dropline/data/weather/wmo.dart';
import 'package:dropline/features/weather/weather_line.dart';

const resort = Resort(id: 'kitz', name: 'Kitzbühel', country: 'AT', lat: 47.4467, lon: 12.3923, radiusKm: 12, baseAltM: 800, summitAltM: 2000);

void main() {
  test('parses base + summit and formats the line', () async {
    final client = MockClient((req) async {
      final elev = req.url.queryParameters['elevation'];
      final temp = elev == '2000' ? -6.5 : -1.2;
      return http.Response(jsonEncode({
        'current': {'temperature_2m': temp, 'wind_speed_10m': 12.0, 'weather_code': 71},
        'daily': {'snowfall_sum': [12.4]},
      }), 200);
    });
    final w = await OpenMeteoClient(client: client).fetch(resort, nowMs: 1);
    expect(w, isNotNull);
    expect(w!.tempBaseC, -1.2);
    expect(w.tempSummitC, -6.5);
    expect(w.freshSnowCm, 12.4);
    expect(wmoBucket(w.wmoCode), WeatherBucket.snow);
    expect(WeatherLine.format(resort, w, de: true), 'Kitzbühel · −7° Berg · 12 cm Neuschnee');
    expect(WeatherLine.format(resort, null, de: true), 'Kitzbühel');
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
