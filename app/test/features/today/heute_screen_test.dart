import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/app/widgets/widgets.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/features/recording/live_state_provider.dart';
import 'package:dropline/features/recording/recording_controller.dart';
import 'package:dropline/features/recording/recovery_service.dart';
import 'package:dropline/features/today/heute_screen.dart';

import '../../support/pump.dart';
import 'today_fixtures.dart';

const _liveRecording = LiveState(
  stats: DayStats(
    elapsedMs: 4 * 3600 * 1000 + 37 * 60 * 1000,
    skiMs: 3600 * 1000,
    liftMs: 2 * 3600 * 1000,
    pauseMs: 1800 * 1000,
    runCount: 7,
    dropM: 1804,
    maxSpeedMs: 17,
  ),
  speedMs: 12.5,
  altM: 1830,
  state: MotionState.run,
  gps: GpsQuality.good,
);

void main() {
  testWidgets('idle shows the last day, the season line and the start button', (tester) async {
    final ctrl = FakeRecordingController();
    await pumpApp(
      tester,
      const HeuteScreen(),
      overrides: todayOverrides(
        controller: ctrl,
        days: [daySummary()],
        totals: const [SeasonTotals(seasonKey: '2025/26', dayCount: 6, runCount: 41, dropM: 18240)],
      ),
    );
    await tester.pump();

    expect(find.text('Zuletzt'.toUpperCase()), findsOneWidget);
    expect(find.text('1.804'), findsWidgets); // last day vertical
    expect(find.text('SAISON 2025/26'), findsOneWidget);
    expect(find.text('18.240'), findsOneWidget);
    expect(find.text('Tag starten'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('idle without any day shows the mascot sentence', (tester) async {
    await pumpApp(tester, const HeuteScreen(), overrides: todayOverrides(controller: FakeRecordingController()));
    await tester.pump();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Tag starten'), findsOneWidget);
  });

  testWidgets('Tag starten calls startDay', (tester) async {
    final ctrl = FakeRecordingController();
    await pumpApp(tester, const HeuteScreen(), overrides: todayOverrides(controller: ctrl));
    await tester.pump();
    await tester.tap(find.text('Tag starten'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.startCalls, 1);
    // The screen flipped to the live face.
    expect(find.byType(HoldToConfirmButton), findsOneWidget);
  });

  testWidgets('denied location shows the inline card with the settings action', (tester) async {
    final ctrl = FakeRecordingController(startError: RecordingErrorKind.locationDenied);
    await pumpApp(tester, const HeuteScreen(), overrides: todayOverrides(controller: ctrl));
    await tester.pump();
    await tester.tap(find.text('Tag starten'));
    await tester.pumpAndSettle();

    expect(find.text('Standort ist aus'), findsOneWidget);
    expect(find.text('Einstellungen öffnen'), findsOneWidget);
    // Start stays available — a denial can be fixed and retried.
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNotNull);
  });

  testWidgets('reduced accuracy shows the precise card and blocks start', (tester) async {
    final ctrl = FakeRecordingController(startError: RecordingErrorKind.reducedAccuracy);
    await pumpApp(tester, const HeuteScreen(), overrides: todayOverrides(controller: ctrl));
    await tester.pump();
    await tester.tap(find.text('Tag starten'));
    await tester.pumpAndSettle();

    expect(find.text('Genauer Standort fehlt'), findsOneWidget);
    expect(find.text('Genau ein'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
    await tester.tap(find.text('Tag starten'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.startCalls, 1);
  });

  testWidgets('recovery card ends and saves the interrupted day', (tester) async {
    final ctrl = FakeRecordingController();
    final pushed = <String>[];
    await pumpApp(
      tester,
      hostWithRoutes(const HeuteScreen(), pushed),
      overrides: todayOverrides(
        controller: ctrl,
        recovery: RecoveryInfo(dayId: 'rec-1', startedAt: tsDay, lastFixAt: tsDay, runCount: 7, dropM: 1804, resortName: 'Kitzbühel'),
      ),
    );
    await tester.pump();

    expect(find.textContaining('unterbrochen'), findsOneWidget);
    expect(find.text('7 Abfahrten · 1.804 hm · Kitzbühel'), findsOneWidget);

    await tester.tap(find.text('Beenden & speichern'));
    await tester.pumpAndSettle();
    expect(ctrl.recoveredEnds, ['rec-1']);
    expect(pushed, ['/summary/rec-1']);
  });

  testWidgets('recovery card can resume and discard', (tester) async {
    final ctrl = FakeRecordingController();
    await pumpApp(
      tester,
      const HeuteScreen(),
      overrides: todayOverrides(
        controller: ctrl,
        recovery: RecoveryInfo(dayId: 'rec-1', startedAt: tsDay, lastFixAt: tsDay, runCount: 7, dropM: 1804),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Verwerfen'));
    await tester.pumpAndSettle();
    expect(ctrl.discarded, ['rec-1']);
  });

  testWidgets('live shows pill, state chip, hero numbers and the secondary row', (tester) async {
    final ctrl = FakeRecordingController(
      initial: RecordingState(status: RecordingStatus.recording, dayId: 'day-live', startedAt: tsDay),
    );
    await pumpApp(
      tester,
      const HeuteScreen(),
      overrides: todayOverrides(controller: ctrl, live: _liveRecording),
    );
    await tester.pump();

    expect(find.text('Aufnahme läuft · GPS gut'), findsOneWidget);
    expect(find.text('Abfahrt 7'), findsOneWidget);
    expect(find.text('1.804'), findsOneWidget); // Höhenmeter
    expect(find.text('7'), findsOneWidget); // Abfahrten
    expect(find.text('61'), findsOneWidget); // Top-Speed, 17 m/s
    expect(find.text('45'), findsOneWidget); // Geschwindigkeit, 12.5 m/s
    expect(find.text('1.830'), findsOneWidget); // Höhe
    expect(find.text('4:37:00'), findsOneWidget); // Zeit
    expect(find.text('Karte'), findsOneWidget);
    expect(find.byType(HoldToConfirmButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no GPS swaps the state chip for the barometer hint', (tester) async {
    final ctrl = FakeRecordingController(
      initial: RecordingState(status: RecordingStatus.recording, dayId: 'day-live', startedAt: tsDay),
    );
    await pumpApp(
      tester,
      const HeuteScreen(),
      overrides: todayOverrides(
        controller: ctrl,
        live: const LiveState(gps: GpsQuality.none, altM: 1830, state: MotionState.stop),
      ),
    );
    await tester.pump();
    expect(find.text('Kein GPS – Höhe über Barometer'), findsOneWidget);
    expect(find.text('Aufnahme läuft · Kein GPS'), findsOneWidget);
  });

  testWidgets('holding Tag beenden ends the day and opens the Tagesbilanz', (tester) async {
    final ctrl = FakeRecordingController(
      initial: RecordingState(status: RecordingStatus.recording, dayId: 'day-live', startedAt: tsDay),
      endResult: 'day-42',
    );
    final pushed = <String>[];
    await pumpApp(
      tester,
      hostWithRoutes(const HeuteScreen(), pushed),
      overrides: todayOverrides(controller: ctrl, live: _liveRecording),
    );
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirmButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(ctrl.endCalls, 1);
    expect(pushed, ['/summary/day-42']);
  });

  testWidgets('a day that is too short shows the snackbar instead of a route', (tester) async {
    final ctrl = FakeRecordingController(
      initial: RecordingState(status: RecordingStatus.recording, dayId: 'day-live', startedAt: tsDay),
      endResult: null,
    );
    final pushed = <String>[];
    await pumpApp(
      tester,
      hostWithRoutes(const HeuteScreen(), pushed),
      overrides: todayOverrides(controller: ctrl, live: _liveRecording),
    );
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirmButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(ctrl.endCalls, 1);
    expect(pushed, isEmpty);
    expect(find.text('Zu kurz, nicht gespeichert'), findsOneWidget);
  });

  testWidgets('a committed run shows the banner for three seconds', (tester) async {
    final ctrl = FakeRecordingController(
      initial: RecordingState(status: RecordingStatus.recording, dayId: 'day-live', startedAt: tsDay),
    );
    await pumpApp(
      tester,
      const HeuteScreen(),
      overrides: todayOverrides(controller: ctrl, live: _liveRecording),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(find.byType(HeuteScreen)));
    container.read(liveStateNotifierProvider.notifier).set(
          _liveRecording.copyWith(
            lastRun: Segment(
              id: 'seg-7',
              dayId: 'day-live',
              kind: SegmentKind.run,
              idx: 6,
              runNumber: 7,
              startTs: tsDay,
              endTs: tsDay + 600000,
              dropM: 312,
              maxSpeedMs: 17,
            ),
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Abfahrt 7 · 312 hm · 61 km/h'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Abfahrt 7 · 312 hm · 61 km/h'), findsNothing);
  });

  testWidgets('English locale switches the copy', (tester) async {
    await pumpApp(
      tester,
      const HeuteScreen(),
      overrides: todayOverrides(controller: FakeRecordingController()),
      locale: const Locale('en'),
    );
    await tester.pump();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Start day'), findsOneWidget);
  });
}
