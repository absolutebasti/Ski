import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/features/days/tage_screen.dart';
import 'package:slopetrack/features/settings/settings_sheet.dart';
import 'package:slopetrack/features/summary/tagesbilanz_screen.dart';
import 'package:slopetrack/features/today/heute_screen.dart';

import '../features/days/day_fixtures.dart';
import '../features/days/golden_fonts.dart';
import '../features/summary/summary_fixture.dart';
import '../support/pump.dart';
import '../support/screen_overrides.dart';

/// Dynamic Type guard (docs/BACKLOG-2.md UX-ONBOARDING-A11Y): the four core
/// screens at TextScaler.linear(1.3) on a 393×852 phone must not throw a
/// RenderFlex overflow. Every overflow is collected with its widget and amount
/// so the failure names the culprit. Real Inter faces are loaded: the test
/// font draws every glyph as a 1 em box, which would overstate widths ~40 %.
const _phone = Size(393, 852);
const _scale = 1.3;

final _bests = PersonalBests(
  topSpeedMs: 17,
  topSpeedDayId: 'a',
  biggestDayDropM: 1804,
  biggestDayId: 'a',
  longestRunDropM: 312,
  longestRunDayId: 'a',
);

/// Swallows RenderFlex overflows into [found] (with widget + amount) and hands
/// every other error to the test binding. [stop] must run before any
/// `expect`: the binding asserts that FlutterError.onError is restored.
class _OverflowCollector {
  _OverflowCollector() {
    _previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        final lines = details.toString().split('\n').map((l) => l.trim()).toList();
        final at = lines.indexWhere((l) => l.contains('error-causing widget was'));
        final culprit = at >= 0 ? lines.skip(at + 1).take(2).join(' ') : '';
        found.add('${text.split('\n').first} — $culprit');
      } else {
        _previous?.call(details);
      }
    };
    addTearDown(stop);
  }

  final List<String> found = [];
  void Function(FlutterErrorDetails)? _previous;
  bool _stopped = false;

  List<String> stop() {
    if (!_stopped) {
      _stopped = true;
      FlutterError.onError = _previous;
    }
    return found;
  }
}

Future<_OverflowCollector> _pumpScaled(WidgetTester tester, Widget child, {List<Override> overrides = const []}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = _scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final overflows = _OverflowCollector();
  await pumpApp(tester, child, overrides: overrides);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  return overflows;
}

void main() {
  setUpAll(loadInterFonts);

  testWidgets('the 1.3× scale really reaches the widgets', (tester) async {
    late TextScaler scaler;
    await _pumpScaled(tester, Builder(builder: (context) {
      scaler = MediaQuery.textScalerOf(context);
      return const SizedBox();
    }));
    expect(scaler.scale(10), closeTo(13, 0.01));
  });

  testWidgets('HeuteScreen idle at 1.3× has no RenderFlex overflow', (tester) async {
    final collector = await _pumpScaled(
      tester,
      const HeuteScreen(),
      overrides: screenOverrides(
        days: [summary(id: 'a', startedAt: tsThisSeason)],
        seasons: const [SeasonTotals(seasonKey: '2025/26', dayCount: 1, runCount: 7, dropM: 1804)],
        bests: _bests,
      ),
    );
    final overflows = collector.stop();
    expect(overflows, isEmpty, reason: overflows.join('\n'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TageScreen at 1.3× has no RenderFlex overflow', (tester) async {
    final collector = await _pumpScaled(
      tester,
      const TageScreen(),
      overrides: screenOverrides(
        days: [
          summary(id: 'a', startedAt: tsThisSeason, isTopSpeedPb: true, isBiggestDayPb: true),
          summary(id: 'b', startedAt: tsThisSeason - 86400000, resortName: 'Sölden – Ötztal'),
          summary(id: 'c', startedAt: tsLastSeason),
        ],
        seasons: const [
          SeasonTotals(seasonKey: '2025/26', dayCount: 2, runCount: 14, dropM: 3608),
          SeasonTotals(seasonKey: '2024/25', dayCount: 1, runCount: 7, dropM: 1804),
        ],
        bests: _bests,
      ),
    );
    final overflows = collector.stop();
    expect(overflows, isEmpty, reason: overflows.join('\n'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TagesbilanzScreen at 1.3× has no RenderFlex overflow', (tester) async {
    final collector = await _pumpScaled(
      tester,
      const TagesbilanzScreen(dayId: 'day-1'),
      overrides: [
        ...screenOverrides(
          days: [summary(id: 'day-1', startedAt: tsThisSeason), summary(id: 'day-0', startedAt: tsThisSeason - 86400000)],
          settings: const Settings(onboardingDone: true, notificationsAsked: true),
        ),
        dayDetailProvider.overrideWith((ref, id) => summaryDetail()),
      ],
    );
    // Scroll through the whole page so every section lays out at least once.
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 6; i++) {
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    final overflows = collector.stop();
    expect(overflows, isEmpty, reason: overflows.join('\n'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsSheet at 1.3× has no RenderFlex overflow', (tester) async {
    final collector = await _pumpScaled(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(child: TextButton(onPressed: () => SettingsSheet.show(context), child: const Text('open'))),
        ),
      ),
      overrides: screenOverrides(),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSheetBody), findsOneWidget);
    final scrollable = find.descendant(of: find.byType(SettingsSheetBody), matching: find.byType(Scrollable));
    if (scrollable.evaluate().isNotEmpty) {
      for (var i = 0; i < 4; i++) {
        await tester.drag(scrollable.first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
    }
    final overflows = collector.stop();
    expect(overflows, isEmpty, reason: overflows.join('\n'));
    expect(tester.takeException(), isNull);
  });
}
