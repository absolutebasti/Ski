import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/settings.dart';
import '../data/db/providers.dart';
import '../features/map/thumbnail_renderer.dart';
import '../platform/permission_service.dart';
import '../tracking/synthetic.dart';
import '../tracking/tracking.dart';

/// Debug-only launch switches (simulator QA and screenshots), in priority order:
///   1. `<Documents>/demo.json` inside the app container, e.g.
///      {"SLOPETRACK_SKIP_ONBOARDING":"1","SLOPETRACK_DEMO":"1","SLOPETRACK_TAB":"tage","SLOPETRACK_ROUTE":"/day/demo-0"}
///      — written with `xcrun simctl get_app_container <udid> <bundle> data`, no rebuild needed (tools/shots.sh)
///   2. `--dart-define=SLOPETRACK_SKIP_ONBOARDING=1` etc. at build time
///   SLOPETRACK_ROUTE: a named route pushed after the first frame, or `settings` / `account` for the sheets.
///   SLOPETRACK_APPEARANCE: system | light | dark (screenshots of the light theme).
class Demo {
  const Demo._();

  static Map<String, String> _file = const {};

  /// demo.json first, runtime env second, build-time --dart-define third.
  static String? _env(String key) {
    if (!kDebugMode) return null;
    final fromFile = _file[key];
    if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    final runtime = Platform.environment[key];
    if (runtime != null && runtime.isNotEmpty) return runtime;
    final defined = switch (key) {
      'SLOPETRACK_SKIP_ONBOARDING' => const String.fromEnvironment('SLOPETRACK_SKIP_ONBOARDING'),
      'SLOPETRACK_DEMO' => const String.fromEnvironment('SLOPETRACK_DEMO'),
      'SLOPETRACK_TAB' => const String.fromEnvironment('SLOPETRACK_TAB'),
      'SLOPETRACK_ROUTE' => const String.fromEnvironment('SLOPETRACK_ROUTE'),
      'SLOPETRACK_APPEARANCE' => const String.fromEnvironment('SLOPETRACK_APPEARANCE'),
      _ => '',
    };
    return defined.isEmpty ? null : defined;
  }

  static Future<void> _loadFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/demo.json');
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _file = m.map((k, v) => MapEntry(k, '$v'));
    } catch (e) {
      debugPrint('demo: demo.json ignored ($e)');
    }
  }
  static bool get skipOnboarding => _env('SLOPETRACK_SKIP_ONBOARDING') == '1';
  static bool get seedDays => _env('SLOPETRACK_DEMO') == '1';
  static int get initialTab => switch (_env('SLOPETRACK_TAB')) { 'tage' => 1, 'rangliste' || 'social' => 2, _ => 0 };
  static String? get initialRoute => _env('SLOPETRACK_ROUTE');

  /// Call before the ProviderContainer is built so [seedDays] can decide the
  /// permission override (simulators never grant Always).
  static Future<void> load() async {
    if (!kDebugMode) return;
    await _loadFile();
  }

  static Future<void> apply(ProviderContainer container) async {
    if (!kDebugMode) return;
    debugPrint('demo: skipOnboarding=$skipOnboarding seedDays=$seedDays tab=$initialTab route=$initialRoute');
    if (skipOnboarding) await container.read(settingsProvider.notifier).setOnboardingDone();
    final appearance = _env('SLOPETRACK_APPEARANCE');
    if (appearance != null) await container.read(settingsProvider.notifier).setAppearance(appearance);
    if (seedDays) await _seed(container);
  }

  static Future<void> _seed(ProviderContainer container) async {
    final repo = container.read(daysRepositoryProvider);
    if ((await repo.watchDays().first).isNotEmpty) return;
    final resorts = [('kitzbuehel', 'Kitzbühel'), ('st-anton', 'St. Anton am Arlberg'), ('soelden', 'Sölden')];
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      final start = DateTime(now.year, now.month, now.day - (i + 1) * 3, 9).millisecondsSinceEpoch;
      final day = SyntheticDayGenerator(seed: 11 + i, startTs: start).generate();
      final engine = TrackingEngine(dayId: 'demo-$i');
      var fi = 0, pi = 0;
      for (var ts = day.pressures.first.ts; ts <= day.pressures.last.ts; ts += 1000) {
        while (fi < day.fixes.length && day.fixes[fi].ts <= ts) {
          engine.addFix(day.fixes[fi++]);
        }
        while (pi < day.pressures.length && day.pressures[pi].ts <= ts) {
          engine.addPressure(day.pressures[pi++]);
        }
        engine.tick(ts);
      }
      final r = engine.finish();
      await repo.createActiveDay(id: 'demo-$i', startedAt: start, resortId: resorts[i].$1, resortName: resorts[i].$2);
      await repo.appendPoints('demo-$i', r.points, stats: r.stats);
      await repo.finishDay('demo-$i', endedAt: r.points.last.ts, stats: r.stats, segments: r.segments);
      try {
        final detail = await repo.dayDetail('demo-$i');
        if (detail != null) await repo.updateMapThumb('demo-$i', await ThumbnailRenderer.render(detail));
      } catch (_) {}
    }
    await container.read(settingsProvider.notifier).update((s) => s.copyWith(lastResortId: 'kitzbuehel'));
  }
}

/// Used by RootShell to pick the initial tab (debug only).
int demoInitialTab() => Demo.initialTab;

/// Used by RootShell to push a screen after the first frame (debug only).
String? demoInitialRoute() => Demo.initialRoute;

/// Demo mode: every permission granted, so screenshots show the product and
/// not the permission cards. Debug builds only (main.dart).
class DemoPermissionService implements PermissionService {
  @override
  Future<LocationPermissionState> status() async => LocationPermissionState.always;
  @override
  Future<LocationPermissionState> requestWhenInUse() async => LocationPermissionState.always;
  @override
  Future<LocationPermissionState> requestAlways() async => LocationPermissionState.always;
  @override
  Future<bool> requestMotion() async => true;
  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<bool> notificationsGranted() async => true;
  @override
  Future<bool> hasPreciseLocation() async => true;
  @override
  Future<bool> requestTemporaryFullAccuracy() async => true;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<void> openSettings() async {}
}
