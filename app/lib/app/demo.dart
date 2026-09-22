import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';
import '../data/db/providers.dart';
import '../tracking/synthetic.dart';
import '../tracking/tracking.dart';

/// Debug-only launch switches (simulator QA and screenshots):
///   SIMCTL_CHILD_SCHWUNG_SKIP_ONBOARDING=1   → onboarding marked done
///   SIMCTL_CHILD_SCHWUNG_DEMO=1              → three synthetic ski days in the database
///   SIMCTL_CHILD_SCHWUNG_TAB=tage            → open the Tage tab first
/// `xcrun simctl launch` forwards SIMCTL_CHILD_* as plain env vars.
class Demo {
  const Demo._();

  static String? _env(String key) => kDebugMode ? Platform.environment[key] : null;
  static bool get skipOnboarding => _env('SCHWUNG_SKIP_ONBOARDING') == '1';
  static bool get seedDays => _env('SCHWUNG_DEMO') == '1';
  static int get initialTab => _env('SCHWUNG_TAB') == 'tage' ? 1 : 0;

  static Future<void> apply(ProviderContainer container) async {
    if (!kDebugMode) return;
    if (skipOnboarding) await container.read(settingsProvider.notifier).setOnboardingDone();
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
    }
    await container.read(settingsProvider.notifier).update((s) => s.copyWith(lastResortId: 'kitzbuehel'));
  }
}

/// Used by RootShell to pick the initial tab (debug only).
int demoInitialTab() => Demo.initialTab;
