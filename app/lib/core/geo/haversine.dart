import 'dart:math' as math;

const double earthRadiusM = 6371000;

/// Great-circle distance in metres.
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Initial bearing in degrees 0–360.
double bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _rad(lat1), phi2 = _rad(lat2), dl = _rad(lon2 - lon1);
  final y = math.sin(dl) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _rad(double deg) => deg * math.pi / 180;
