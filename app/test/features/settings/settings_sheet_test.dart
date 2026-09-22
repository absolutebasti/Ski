import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/settings.dart';
import 'package:dropline/data/db/database.dart';
import 'package:dropline/data/db/days_repository.dart';
import 'package:dropline/data/db/providers.dart';
import 'package:dropline/features/settings/settings_providers.dart';
import 'package:dropline/features/settings/settings_sheet.dart';
import 'package:dropline/platform/permission_service.dart';
import 'package:dropline/platform/providers.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';
import '../today/today_fixtures.dart' show TestSettings;

/// Counts deleteAll instead of wiping a real database file.
class CountingRepository extends DaysRepository {
  CountingRepository() : super(AppDatabase(NativeDatabase.memory()));
  int deleteAllCalls = 0;
  @override
  Future<void> deleteAll() async => deleteAllCalls++;
}

List<Override> settingsOverrides({
  required TestSettings notifier,
  FakePermissionService? permissions,
  DaysRepository? repo,
  LocationPermissionState location = LocationPermissionState.always,
}) =>
    [
      settingsProvider.overrideWith(() => notifier),
      permissionServiceProvider.overrideWithValue(permissions ?? FakePermissionService()),
      locationStatusProvider.overrideWith((ref) async => location),
      appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
      if (repo != null) daysRepositoryProvider.overrideWithValue(repo),
    ];

Settings readSettings(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SettingsSheetBody))).read(settingsProvider);

void main() {
  testWidgets('every row of the sheet is rendered', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: SettingsSheetBody()),
      overrides: settingsOverrides(notifier: TestSettings()),
    );
    await tester.pump();

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Folgt der Sprache'), findsOneWidget);
    expect(find.text('Standortzugriff'), findsOneWidget);
    expect(find.text('Immer'), findsOneWidget);
    expect(find.text('Benachrichtigungen'), findsOneWidget);
    expect(find.text('Datenschutz'), findsOneWidget);
    expect(find.text('Alle Daten löschen'), findsOneWidget);
    expect(find.text('0.1.0 (1)'), findsOneWidget);
    expect(find.text('Diagnose'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a language persists it', (tester) async {
    final notifier = TestSettings();
    await pumpApp(
      tester,
      const Scaffold(body: SettingsSheetBody()),
      overrides: settingsOverrides(notifier: notifier),
    );
    await tester.pump();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(readSettings(tester).locale, 'en');

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(readSettings(tester).locale, 'de');
  });

  testWidgets('the notification switch asks iOS and stores the answer', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: SettingsSheetBody()),
      overrides: settingsOverrides(notifier: TestSettings()),
    );
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final settings = readSettings(tester);
    expect(settings.notificationsOptIn, isTrue);
    expect(settings.notificationsAsked, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(readSettings(tester).notificationsOptIn, isFalse);
  });

  testWidgets('seven taps on the version unlock the diagnostics row', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: SettingsSheetBody()),
      overrides: settingsOverrides(notifier: TestSettings()),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('0.1.0 (1)'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('0.1.0 (1)'));
      await tester.pump();
    }
    expect(find.text('Diagnose'), findsNothing);
    expect(readSettings(tester).diagnosticsUnlocked, isFalse);

    await tester.tap(find.text('0.1.0 (1)'));
    await tester.pumpAndSettle();
    expect(readSettings(tester).diagnosticsUnlocked, isTrue);
    expect(find.text('Diagnose'), findsOneWidget);
  });

  testWidgets('deleting all data needs two confirmations', (tester) async {
    final repo = CountingRepository();
    addTearDown(() async => repo.db.close());
    await pumpApp(
      tester,
      const Scaffold(body: SettingsSheetBody()),
      overrides: settingsOverrides(notifier: TestSettings(), repo: repo),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Alle Daten löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle Daten löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Alle Skitage löschen?'), findsOneWidget);

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Wirklich endgültig löschen?'), findsOneWidget);
    expect(repo.deleteAllCalls, 0);

    await tester.tap(find.text('Endgültig löschen'));
    await tester.pumpAndSettle();
    expect(repo.deleteAllCalls, 1);
    expect(find.text('Alle Daten gelöscht'), findsOneWidget);
  });

  testWidgets('cancelling the first confirmation keeps everything', (tester) async {
    final repo = CountingRepository();
    addTearDown(() async => repo.db.close());
    await pumpApp(
      tester,
      const Scaffold(body: SettingsSheetBody()),
      overrides: settingsOverrides(notifier: TestSettings(), repo: repo),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Alle Daten löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle Daten löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repo.deleteAllCalls, 0);
  });

  testWidgets('a denied location shows up in the row', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: SettingsSheetBody()),
      overrides: settingsOverrides(notifier: TestSettings(), location: LocationPermissionState.denied),
    );
    await tester.pump();
    expect(find.text('Nicht erlaubt'), findsOneWidget);
    expect(find.text('Einstellungen öffnen'), findsOneWidget);
  });

  testWidgets('English locale switches the copy', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: SettingsSheetBody()),
      overrides: settingsOverrides(notifier: TestSettings()),
      locale: const Locale('en'),
    );
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Follows the language'), findsOneWidget);
    expect(find.text('Delete all data'), findsOneWidget);
  });
}
