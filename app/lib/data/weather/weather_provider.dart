import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/core.dart';
import 'open_meteo_client.dart';

final openMeteoClientProvider = Provider<OpenMeteoClient>((ref) => OpenMeteoClient());

/// Cached per resort for 30 min (memory + shared_preferences). Never throws.
class WeatherCache {
  WeatherCache({this.ttl = const Duration(minutes: 30)});
  final Duration ttl;
  final _mem = <String, WeatherSnapshot>{};

  Future<WeatherSnapshot?> get(String resortId, int nowMs) async {
    final m = _mem[resortId];
    if (m != null && nowMs - m.fetchedAt < ttl.inMilliseconds) return m;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('weather.$resortId');
      if (raw != null) {
        final s = WeatherSnapshot.fromJson(_decode(raw));
        if (nowMs - s.fetchedAt < ttl.inMilliseconds) {
          _mem[resortId] = s;
          return s;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> put(String resortId, WeatherSnapshot s) async {
    _mem[resortId] = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('weather.$resortId', _encode(s.toJson()));
    } catch (_) {}
  }

  static Map<String, Object?> _decode(String raw) {
    final out = <String, Object?>{};
    for (final part in raw.split('|')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      final k = part.substring(0, i), v = part.substring(i + 1);
      out[k] = v == 'null' ? null : num.tryParse(v) ?? v;
    }
    return out;
  }

  static String _encode(Map<String, Object?> m) => m.entries.map((e) => '${e.key}=${e.value}').join('|');
}

final weatherCacheProvider = Provider<WeatherCache>((ref) => WeatherCache());

final weatherProvider = FutureProvider.family<WeatherSnapshot?, Resort>((ref, resort) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final cache = ref.watch(weatherCacheProvider);
  final cached = await cache.get(resort.id, now);
  if (cached != null) return cached;
  final fresh = await ref.watch(openMeteoClientProvider).fetch(resort, nowMs: now);
  if (fresh != null) await cache.put(resort.id, fresh);
  return fresh;
});
