import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';

/// Bundled resort centres (assets/data/resorts.json — OpenSkiMap / OpenStreetMap,
/// ODbL; built by tools/data/import_resorts.py). Loaded once.
///
/// Since DATA-RESORTS-2 the file is de-duplicated: sub-areas of a Verbund and
/// exact duplicates are folded into one entry whose `aliases` list carries the
/// retired ids. [byId] and [canonicalId] resolve those, so days stored with an
/// old id (`lech-zuers`, `damuls-at-4f8cc7` …) still find their resort.
class ResortRepository {
  ResortRepository(this._resorts, {Map<String, String> aliases = const {}}) : _aliases = Map.unmodifiable(aliases);

  final List<Resort> _resorts;
  /// alias id → canonical id.
  final Map<String, String> _aliases;
  late final Map<String, Resort> _byId = {for (final r in _resorts.reversed) r.id: r}; // first entry wins

  static Future<ResortRepository> load() async {
    final raw = await rootBundle.loadString('assets/data/resorts.json');
    return ResortRepository.fromJsonString(raw);
  }

  /// Parses the resorts.json format (entries may carry `aliases: [id, …]`).
  factory ResortRepository.fromJsonString(String raw) {
    final list = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
    final aliases = <String, String>{};
    for (final j in list) {
      final id = j['id'] as String;
      for (final a in (j['aliases'] as List?) ?? const []) {
        aliases[a as String] = id;
      }
    }
    return ResortRepository(list.map(Resort.fromJson).toList(), aliases: aliases);
  }

  List<Resort> get all => List.unmodifiable(_resorts);

  /// alias id → canonical id for every retired id in the bundle.
  Map<String, String> get aliases => _aliases;

  /// The id to store and to send to the server: aliases resolve to their
  /// canonical entry, unknown ids pass through unchanged.
  String canonicalId(String id) => _aliases[id] ?? id;

  /// Resort by canonical id or by one of its aliases.
  Resort? byId(String id) => _byId[canonicalId(id)];

  /// Resort whose radius contains the point, else null.
  ///
  /// When several circles contain the point, a resort that lies entirely inside
  /// another candidate's circle counts as a sub-area of that Verbund and loses to
  /// it (Sonnenkopf inside Ski Arlberg). Among the remaining candidates the
  /// nearest centre wins, so two neighbours with overlapping rims (Kitzbühel and
  /// the SkiWelt) still split by proximity.
  ///
  /// ~4.600 resorts (OpenSkiMap import): a degree-box pre-check skips the
  /// haversine for everything farther than the largest radius (18 km).
  Resort? nearest(double lat, double lon) {
    const maxDeg = 0.2; // 18 km at the equator, generous elsewhere
    final hits = <(Resort, double)>[];
    for (final r in _resorts) {
      if ((r.lat - lat).abs() > maxDeg || (r.lon - lon).abs() > maxDeg * 2) continue;
      final d = haversineM(lat, lon, r.lat, r.lon);
      if (d <= r.radiusKm * 1000) hits.add((r, d));
    }
    if (hits.isEmpty) return null;
    if (hits.length == 1) return hits.single.$1;
    hits.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (r, _) in hits) {
      final enclosed = hits.any((o) => o.$1 != r && _encloses(o.$1, r));
      if (!enclosed) return r;
    }
    return hits.first.$1;
  }

  /// True when [small]'s circle lies (almost) entirely inside [big]'s.
  static bool _encloses(Resort big, Resort small) {
    if (big.radiusKm <= small.radiusKm) return false;
    final d = haversineM(big.lat, big.lon, small.lat, small.lon) / 1000;
    return d + small.radiusKm <= big.radiusKm * 1.1;
  }
}

final resortRepositoryProvider = FutureProvider<ResortRepository>((ref) => ResortRepository.load());
