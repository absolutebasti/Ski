import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/app/widgets/widgets.dart';

import '../../support/pump.dart';

Widget _reduced(Widget child, {bool disable = true}) => MediaQuery(data: MediaQueryData(disableAnimations: disable), child: child);

const _tabs = [AppTab(label: 'Heute', glyph: Glyph.chevron), AppTab(label: 'Tage', glyph: Glyph.calendar), AppTab(label: 'Rangliste', glyph: Glyph.podium)];

/// Opacity of the first FadeTransition under [of].
double _fade(WidgetTester tester, Finder of) => tester.widget<FadeTransition>(find.descendant(of: of, matching: find.byType(FadeTransition)).first).opacity.value;

void main() {
  group('RecordingPill', () {
    testWidgets('reduced motion: static dot at full opacity, no ticker, settles', (tester) async {
      await pumpApp(tester, _reduced(const Scaffold(body: Center(child: RecordingPill(text: 'Aufnahme läuft')))));
      await tester.pumpAndSettle(); // would time out with a repeating controller
      expect(tester.hasRunningAnimations, isFalse);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(_fade(tester, find.byType(RecordingPill)), 1.0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_fade(tester, find.byType(RecordingPill)), 1.0);
    });

    testWidgets('normal motion: the dot still pulses between 0.35 and 1', (tester) async {
      await pumpApp(tester, const Scaffold(body: Center(child: RecordingPill(text: 'Aufnahme läuft'))));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      final seen = <double>{};
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        seen.add(_fade(tester, find.byType(RecordingPill)));
      }
      expect(seen.length, greaterThan(3));
      expect(seen.every((v) => v >= 0.35 - 1e-9 && v <= 1.0 + 1e-9), isTrue);
    });

    testWidgets('an inactive pill holds no ticker either', (tester) async {
      await pumpApp(tester, const Scaffold(body: Center(child: RecordingPill(text: 'Pausiert', active: false))));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_fade(tester, find.byType(RecordingPill)), 1.0);
    });

    testWidgets('the pulse stops when reduced motion is switched on and resumes when it is switched off', (tester) async {
      final disable = ValueNotifier(false);
      addTearDown(disable.dispose);
      await pumpApp(
        tester,
        ValueListenableBuilder(
          valueListenable: disable,
          builder: (_, off, _) => _reduced(const Scaffold(body: Center(child: RecordingPill(text: 'Aufnahme läuft'))), disable: off),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);

      disable.value = true;
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_fade(tester, find.byType(RecordingPill)), 1.0);

      disable.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      expect(_fade(tester, find.byType(RecordingPill)), lessThan(1.0));
    });

    testWidgets('pausing the recording stops the pulse, resuming restarts it', (tester) async {
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await pumpApp(
        tester,
        ValueListenableBuilder(
          valueListenable: active,
          builder: (_, on, _) => Scaffold(body: Center(child: RecordingPill(text: 'Aufnahme', active: on))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      active.value = false;
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      active.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('AppTabBar recording pulse', () {
    Widget bar({bool recording = true, int index = 0}) => Scaffold(bottomNavigationBar: AppTabBar(tabs: _tabs, index: index, onSelect: (_) {}, recording: recording));

    testWidgets('reduced motion: static ring at its end value, no ticker, settles', (tester) async {
      await pumpApp(tester, _reduced(bar()));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      // The ring is still drawn (recording stays visible), at the pulse's peak: controller value 1.
      expect(_fade(tester, find.byType(AppTabBar)), moreOrLessEquals(0.9));
      await tester.pump(const Duration(milliseconds: 600));
      expect(_fade(tester, find.byType(AppTabBar)), moreOrLessEquals(0.9));
    });

    testWidgets('reduced motion: switching tabs moves the accent bar without an animation', (tester) async {
      final index = ValueNotifier(0);
      addTearDown(index.dispose);
      await pumpApp(tester, ValueListenableBuilder(valueListenable: index, builder: (_, i, _) => _reduced(bar(recording: false, index: i))));
      await tester.pumpAndSettle();
      index.value = 1;
      await tester.pump();
      final bars = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      expect(bars, hasLength(3));
      expect(bars.every((c) => c.duration == Duration.zero), isTrue);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('normal motion: the accent bar keeps its 220 ms move', (tester) async {
      await pumpApp(tester, bar(recording: false));
      final bars = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(bars.every((c) => c.duration == Tokens.medium), isTrue);
    });

    testWidgets('normal motion: the ring pulses while recording and stops afterwards', (tester) async {
      final recording = ValueNotifier(true);
      addTearDown(recording.dispose);
      await pumpApp(tester, ValueListenableBuilder(valueListenable: recording, builder: (_, on, _) => bar(recording: on)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      final a = _fade(tester, find.byType(AppTabBar));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_fade(tester, find.byType(AppTabBar)), isNot(a));

      recording.value = false;
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.descendant(of: find.byType(AppTabBar), matching: find.byType(FadeTransition)), findsNothing);
    });

    testWidgets('reduced motion: recording that starts later shows the static ring', (tester) async {
      final recording = ValueNotifier(false);
      addTearDown(recording.dispose);
      await pumpApp(tester, ValueListenableBuilder(valueListenable: recording, builder: (_, on, _) => _reduced(bar(recording: on))));
      await tester.pumpAndSettle();
      recording.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_fade(tester, find.byType(AppTabBar)), moreOrLessEquals(0.9));
    });
  });

  group('Pressable', () {
    Widget pressable() => Scaffold(body: Center(child: Pressable(onTap: () {}, child: const SizedBox(width: 120, height: 60))));

    testWidgets('reduced motion: press scale and opacity use Duration.zero and land at once', (tester) async {
      await pumpApp(tester, _reduced(pressable()));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Duration.zero);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration, Duration.zero);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump(const Duration(milliseconds: 150)); // past the tap-down timeout
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.985);
      final scale = tester.widget<ScaleTransition>(find.descendant(of: find.byType(Pressable), matching: find.byType(ScaleTransition)));
      expect(scale.scale.value, 0.985); // already at the end value, nothing in flight
      expect(tester.hasRunningAnimations, isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('normal motion: press feedback keeps the 120 ms token', (tester) async {
      await pumpApp(tester, pressable());
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Tokens.fast);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration, Tokens.fast);
    });

    testWidgets('PrimaryButton and tappable AppCard inherit the zero press duration', (tester) async {
      await pumpApp(
        tester,
        _reduced(
          Scaffold(
            body: Column(
              children: [
                PrimaryButton(label: 'Tag starten', onPressed: () {}),
                AppCard(onTap: () {}, child: const Text('Karte')),
              ],
            ),
          ),
        ),
      );
      final scales = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale)).toList();
      expect(scales, hasLength(2));
      expect(scales.every((s) => s.duration == Duration.zero), isTrue);
      await tester.pumpAndSettle();
    });
  });
}
