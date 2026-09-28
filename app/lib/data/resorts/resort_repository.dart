import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';

/// Bundled resort centres (assets/data/resorts.json — OpenSkiMap / OpenStreetMap,
/// ODbL; built by tools/data/import_resorts.py). Loaded once.
class ResortRepository {
  ResortRepository(this._resorts);
  final List<Resort> _resorts;

  static Future<ResortRepository> load() async {
    final raw = await rootBundle.loadString('assets/data/resorts.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
    return ResortRepository(list.map(Resort.fromJson).toList());
  }

  List<Resort> get all => List.unmodifiable(_resorts);

  Resort? byId(String id) => _resorts.where((r) => r.id == id).firstOrNull;

  /// Nearest resort whose radius contains the point, else null.
  ///
  /// ~7.000 resorts (OpenSkiMap import): a degree-box pre-check skips the
  /// haversine for everything farther than the largest radius (18 km).
  Resort? nearest(double lat, double lon) {
    Resort? best;
    double bestD = double.infinity;
    const maxDeg = 0.2; // 18 km at the equator, generous elsewhere
    for (final r in _resorts) {
      if ((r.lat - lat).abs() > maxDeg || (r.lon - lon).abs() > maxDeg * 2) continue;
      final d = haversineM(lat, lon, r.lat, r.lon);
      if (d <= r.radiusKm * 1000 && d < bestD) {
        bestD = d;
        best = r;
      }
    }
    return best;
  }
}

final resortRepositoryProvider = FutureProvider<ResortRepository>((ref) => ResortRepository.load());
