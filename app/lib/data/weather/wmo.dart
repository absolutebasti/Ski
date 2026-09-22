import 'package:flutter/material.dart';

/// WMO weather codes collapsed into 8 buckets.
enum WeatherBucket { clear, partlyCloudy, cloudy, fog, rain, snow, thunder, unknown }

WeatherBucket wmoBucket(int? code) {
  if (code == null) return WeatherBucket.unknown;
  if (code == 0) return WeatherBucket.clear;
  if (code <= 2) return WeatherBucket.partlyCloudy;
  if (code == 3) return WeatherBucket.cloudy;
  if (code == 45 || code == 48) return WeatherBucket.fog;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return WeatherBucket.rain;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return WeatherBucket.snow;
  if (code >= 95) return WeatherBucket.thunder;
  return WeatherBucket.unknown;
}

IconData wmoIcon(WeatherBucket b) => switch (b) {
      WeatherBucket.clear => Icons.wb_sunny_rounded,
      WeatherBucket.partlyCloudy => Icons.wb_cloudy_rounded,
      WeatherBucket.cloudy => Icons.cloud_rounded,
      WeatherBucket.fog => Icons.foggy,
      WeatherBucket.rain => Icons.water_drop_rounded,
      WeatherBucket.snow => Icons.ac_unit_rounded,
      WeatherBucket.thunder => Icons.thunderstorm_rounded,
      WeatherBucket.unknown => Icons.help_outline_rounded,
    };

String wmoWord(WeatherBucket b, {required bool de}) => switch (b) {
      WeatherBucket.clear => de ? 'Sonnig' : 'Sunny',
      WeatherBucket.partlyCloudy => de ? 'Leicht bewölkt' : 'Partly cloudy',
      WeatherBucket.cloudy => de ? 'Bewölkt' : 'Cloudy',
      WeatherBucket.fog => de ? 'Nebel' : 'Fog',
      WeatherBucket.rain => de ? 'Regen' : 'Rain',
      WeatherBucket.snow => de ? 'Schneefall' : 'Snowfall',
      WeatherBucket.thunder => de ? 'Gewitter' : 'Thunderstorm',
      WeatherBucket.unknown => '',
    };
