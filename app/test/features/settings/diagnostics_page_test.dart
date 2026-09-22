import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:schwung/core/core.dart';
import 'package:schwung/data/db/providers.dart';
import 'package:schwung/features/recording/live_state_provider.dart';
import 'package:schwung/features/recording/recording_controller.dart';
import 'package:schwung/features/settings/diagnostics_page.dart';
import 'package:schwung/features/settings/settings_providers.dart';
import 'package:schwung/platform/permission_service.dart';
import 'package:schwung/platform/providers.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';
import '../today/today_fixtures.dart' show FakeRecordingController, SeededLive, daySummary;

const _live = LiveState(stats: DayStats(acceptedFixes: 1234, rejectedFixes: 12));

List<Override> diagnosticsOverrides({
  required FakeRecordingController controller,
  List<DaySummary> days = const [],
  LocationSource? location,
}) =>
    [
      recordingControllerProvider.overrideWith(() => controller),
      liveStateNotifierProvider.overrideWith(() => SeededLive(_live)),
      daysListProvider.overrideWith((ref) => Stream.value(days)),
      locationStatusProvider.overrideWith((ref) async => LocationPermissionState.always),
      preciseLocationProvider.overrideWith((ref) async => true),
      barometerAvailableProvider.overrideWith((ref) async => true),
      locationSourceProvider.overrideWithValue(location ?? ManualLocationSource()),
    ];

void main() {
  testWidgets('sensor status and today\'s fix counters are listed', (tester) async {
    final loc = ManualLocationSource()..restarts = 3;
    await pumpApp(
      tester,
      const DiagnosticsPage(),
      overrides: diagnosticsOverrides(controller: FakeRecordingController(), days: [daySummary()], location: loc),
    );
    await tester.pumpAndSettle();

    expect(find.text('Diagnose'), findsOneWidget);
    expect(find.text('Immer'), findsOneWidget);
    expect(find.text('1.234 akzeptiert · 12 verworfen'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // stream restarts
    expect(find.text('Neu berechnen'), findsOneWidget);
    expect(find.text('Diagnosepaket teilen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Neu berechnen runs the engine over the selected day', (tester) async {
    final ctrl = FakeRecordingController();
    await pumpApp(
      tester,
      const DiagnosticsPage(),
      overrides: diagnosticsOverrides(controller: ctrl, days: [daySummary(id: 'day-7')]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Neu berechnen'));
    await tester.pumpAndSettle();
    expect(ctrl.recomputed, ['day-7']);
    expect(find.text('Neu berechnet'), findsOneWidget);
  });

  testWidgets('without a stored day the tools are hidden', (tester) async {
    await pumpApp(
      tester,
      const DiagnosticsPage(),
      overrides: diagnosticsOverrides(controller: FakeRecordingController()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Noch kein Skitag gespeichert.'), findsOneWidget);
    expect(find.text('Neu berechnen'), findsNothing);
  });
}
