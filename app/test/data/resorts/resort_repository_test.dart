import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/resorts/resort_repository.dart';

/// The bundled file, read the way ResortRepository.load() parses it
/// (tests run with the app folder as working directory).
final String _raw = File('assets/data/resorts.json').readAsStringSync();
final ResortRepository _real = ResortRepository.fromJsonString(_raw);
final List<Map<String, Object?>> _json = (jsonDecode(_raw) as List).cast<Map<String, Object?>>();

Resort _r(String id, double lat, double lon, double radiusKm) =>
    Resort(id: id, name: id, country: 'AT', lat: lat, lon: lon, radiusKm: radiusKm);

void main() {
  group('real resorts.json: Verbund before Teilgebiet', () {
    test('St. Anton, St. Christoph, Stuben, Zürs, Lech and Warth resolve to one id (st-anton)', () {
      const points = {
        'St. Anton': (47.1297, 10.2683),
        'St. Christoph': (47.1317, 10.1917),
        'Stuben': (47.1290, 10.1580),
        'Zürs': (47.1703, 10.1597),
        'Lech': (47.2081, 10.1411),
        'Warth': (47.2560, 10.1850),
      };
      final ids = {for (final e in points.entries) e.key: _real.nearest(e.value.$1, e.value.$2)?.id};
      expect(ids.values.toSet(), {'st-anton'}, reason: '$ids');
    });

    test('Damüls, Mellau and Faschina resolve to one id', () {
      const points = {
        'Damüls': (47.2869, 9.8906),
        'Mellau': (47.3500, 9.8811),
        'Faschina': (47.2667, 9.9167),
      };
      final ids = {for (final e in points.entries) e.key: _real.nearest(e.value.$1, e.value.$2)?.id};
      expect(ids.values.toSet(), hasLength(1), reason: '$ids');
      expect(ids.values.first, isNotNull);
    });

    test('the three Damüls variants of the old file are aliases of that one entry', () {
      const variants = ['damuls-at-4f8cc7', 'skigebiet-damuls-mellau-at-f83cb9', 'skigebiet-damuls-mellau-faschina-at-da710e'];
      final resolved = {for (final v in variants) _real.byId(v)?.id};
      expect(resolved, hasLength(1));
      expect(resolved.single, _real.nearest(47.2869, 9.8906)!.id);
    });

    test('retired Arlberg ids resolve to st-anton', () {
      for (final old in ['lech-zuers', 'warth-schrocken-at-29248a', 'ski-arlberg-at-53410f', 'ski-arlberg-at-1dc7dc']) {
        expect(_real.canonicalId(old), 'st-anton', reason: old);
        expect(_real.byId(old)?.id, 'st-anton', reason: old);
      }
      expect(_real.canonicalId('kitzbuehel'), 'kitzbuehel');
      expect(_real.canonicalId('no-such-resort'), 'no-such-resort');
      expect(_real.byId('no-such-resort'), isNull);
    });

    test('neighbours with their own lifts keep their own id', () {
      expect(_real.nearest(47.4467, 12.3914)?.id, 'kitzbuehel'); // Kitzbühel town, next to the SkiWelt
      expect(_real.nearest(46.9690, 11.0070)?.id, 'soelden');
      expect(_real.nearest(46.9800, 10.3100)?.id, 'ischgl');
      expect(_real.nearest(52.52, 13.40), isNull); // Berlin
    });
  });

  group('real resorts.json: integrity', () {
    test('curated ids of the first release are canonical ids, never aliases of a generated id', () {
      final curated = (jsonDecode(File('../tools/data/curated.json').readAsStringSync()) as List).cast<Map<String, Object?>>();
      for (final c in curated) {
        final id = c['id'] as String;
        final resolved = _real.canonicalId(id);
        expect(_real.byId(id), isNotNull, reason: id);
        // a curated id may only fold into another curated id (lech-zuers → st-anton)
        expect(curated.any((o) => o['id'] == resolved), isTrue, reason: '$id → $resolved');
      }
      for (final id in ['kitzbuehel', 'st-anton', 'soelden', 'ischgl', 'zermatt']) {
        expect(_real.aliases.containsKey(id), isFalse, reason: id);
      }
    });

    test('ids unique, aliases unique and never a canonical id', () {
      final ids = [for (final e in _json) e['id'] as String];
      expect(ids.toSet().length, ids.length);
      final aliases = [for (final e in _json) ...((e['aliases'] as List?) ?? const []).cast<String>()];
      expect(aliases.toSet().length, aliases.length);
      expect(aliases.toSet().intersection(ids.toSet()), isEmpty);
      expect(_real.aliases.length, aliases.length);
    });

    test('no exact name + country duplicates', () {
      final seen = <String, int>{};
      for (final r in _real.all) {
        final k = '${r.name.toLowerCase()}|${r.country}';
        seen[k] = (seen[k] ?? 0) + 1;
      }
      expect(seen.entries.where((e) => e.value > 1).map((e) => e.key), isEmpty);
    });

    test('altitudes: filled for almost all, the rest carries neither value', () {
      final missing = _real.all.where((r) => r.baseAltM == null || r.summitAltM == null).toList();
      expect(missing.length, lessThan(20), reason: missing.map((r) => r.name).join(', '));
      for (final r in missing) {
        expect(r.baseAltM, isNull, reason: r.id);
        expect(r.summitAltM, isNull, reason: r.id);
      }
      for (final r in _real.all.where((r) => r.baseAltM != null && r.summitAltM != null)) {
        expect(r.baseAltM!, lessThanOrEqualTo(r.summitAltM!), reason: r.id);
      }
    });

    test('radius stays within the 18 km the bbox pre-check assumes', () {
      expect(_real.all.map((r) => r.radiusKm).reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(18.0));
    });
  });

  group('nearest() on overlap', () {
    test('a resort entirely inside a larger circle loses to the larger one', () {
      final repo = ResortRepository([
        _r('verbund', 47.0, 10.0, 10),
        _r('teil', 47.03, 10.02, 2), // ~3.9 km from the Verbund centre, fully inside
      ]);
      expect(repo.nearest(47.03, 10.02)?.id, 'verbund');
    });

    test('two neighbours whose rims overlap split by proximity', () {
      final repo = ResortRepository([
        _r('west', 47.0, 10.0, 6),
        _r('east', 47.0, 10.12, 5), // ~9 km apart, neither encloses the other
      ]);
      expect(repo.nearest(47.0, 10.04)?.id, 'west');
      expect(repo.nearest(47.0, 10.09)?.id, 'east');
    });

    test('a single hit and no hit', () {
      final repo = ResortRepository([_r('solo', 47.0, 10.0, 3)]);
      expect(repo.nearest(47.01, 10.01)?.id, 'solo');
      expect(repo.nearest(47.2, 10.0), isNull);
    });

    test('fromJsonString reads aliases; byId resolves them', () {
      final repo = ResortRepository.fromJsonString(jsonEncode([
        {'id': 'big', 'name': 'Big', 'country': 'AT', 'lat': 47.0, 'lon': 10.0, 'radiusKm': 8.0, 'aliases': ['old-small']},
        {'id': 'other', 'name': 'Other', 'country': 'AT', 'lat': 48.0, 'lon': 11.0, 'radiusKm': 2.0},
      ]));
      expect(repo.all, hasLength(2));
      expect(repo.byId('old-small')?.id, 'big');
      expect(repo.canonicalId('old-small'), 'big');
      expect(repo.byId('other')?.baseAltM, isNull);
    });
  });
}
