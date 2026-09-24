import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/brand.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/features/account/account.dart';
import 'package:slopetrack/features/settings/settings_providers.dart';
import 'package:slopetrack/features/settings/settings_sheet.dart';
import 'package:slopetrack/platform/permission_service.dart';
import 'package:slopetrack/platform/providers.dart';

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

/// Counts the jumps into the iOS settings app.
class CountingPermissions extends FakePermissionService {
  CountingPermissions({super.state});
  int openedSettings = 0;
  @override
  Future<void> openSettings() async => openedSettings++;
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

/// Opens the real sheet through its public API, so the AppSheet header,
/// the grouped surfaces and the footer are all under test.
Future<void> openSheet(
  WidgetTester tester, {
  required List<Override> overrides,
  Locale locale = const Locale('de'),
  VoidCallback? onAccount,
}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () => SettingsSheet.show(context, onAccount: onAccount), child: const Text('open')),
        ),
      ),
    ),
    overrides: overrides,
    locale: locale,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Lets a toast run out so no timer survives the test.
Future<void> settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

Settings readSettings(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SettingsSheetBody))).read(settingsProvider);

/// The nth segmented control in the sheet (0 = Erscheinungsbild, 1 = Sprache).
Finder tabLabel(int group, String label) =>
    find.descendant(of: find.byType(SegmentedTextTabs).at(group), matching: find.text(label));

void main() {
  testWidgets('every group of the sheet is rendered', (tester) async {
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings()));

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('ALLGEMEIN'), findsOneWidget);
    expect(find.text('Erscheinungsbild'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Folgt der Sprache'), findsOneWidget);
    expect(find.byType(AccountRow), findsOneWidget);
    expect(find.text('Standortzugriff'), findsOneWidget);
    expect(find.text('Immer'), findsOneWidget);
    expect(find.text('Benachrichtigungen'), findsOneWidget);
    expect(find.text('Datenschutz'), findsOneWidget);
    expect(find.text('Alle Daten löschen'), findsOneWidget);
    expect(find.text(kAppName), findsOneWidget);
    expect(find.text('0.1.0 (1)'), findsOneWidget);
    expect(find.text('Diagnose'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Erscheinungsbild tabs drive the appearance setting', (tester) async {
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings()));
    expect(readSettings(tester).appearance, 'dark');

    await tester.tap(tabLabel(0, 'Hell'));
    await tester.pumpAndSettle();
    expect(readSettings(tester).appearance, 'light');
    expect(readSettings(tester).themeMode, ThemeMode.light);

    await tester.tap(tabLabel(0, 'System'));
    await tester.pumpAndSettle();
    expect(readSettings(tester).appearance, 'system');

    await tester.tap(tabLabel(0, 'Dunkel'));
    await tester.pumpAndSettle();
    expect(readSettings(tester).appearance, 'dark');
  });

  testWidgets('picking a language persists it', (tester) async {
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings()));

    await tester.tap(tabLabel(1, 'English'));
    await tester.pumpAndSettle();
    expect(readSettings(tester).locale, 'en');

    await tester.tap(tabLabel(1, 'Deutsch'));
    await tester.pumpAndSettle();
    expect(readSettings(tester).locale, 'de');
  });

  testWidgets('the notification switch asks iOS and stores the answer', (tester) async {
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings()));

    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final settings = readSettings(tester);
    expect(settings.notificationsOptIn, isTrue);
    expect(settings.notificationsAsked, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(readSettings(tester).notificationsOptIn, isFalse);
  });

  testWidgets('without onAccount the Konto row opens the account sheet', (tester) async {
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings()));

    await tester.tap(find.byType(AccountRow));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSheetBody), findsOneWidget);
  });

  testWidgets('with onAccount wired the Konto row calls it', (tester) async {
    var opened = 0;
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings()), onAccount: () => opened++);

    await tester.tap(find.byType(AccountRow));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byType(AccountSheetBody), findsNothing);
  });

  testWidgets('seven taps on the footer version unlock the diagnostics row', (tester) async {
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings()));

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
    await settleToast(tester);
  });

  testWidgets('deleting all data needs two confirmations', (tester) async {
    final repo = CountingRepository();
    addTearDown(() async => repo.db.close());
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings(), repo: repo));

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
    await settleToast(tester);
  });

  testWidgets('cancelling the first confirmation keeps everything', (tester) async {
    final repo = CountingRepository();
    addTearDown(() async => repo.db.close());
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings(), repo: repo));

    await tester.ensureVisible(find.text('Alle Daten löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle Daten löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repo.deleteAllCalls, 0);
  });

  testWidgets('a denied location shows the hint and jumps into the iOS settings', (tester) async {
    final permissions = CountingPermissions(state: LocationPermissionState.denied);
    await openSheet(
      tester,
      overrides: settingsOverrides(notifier: TestSettings(), permissions: permissions, location: LocationPermissionState.denied),
    );
    expect(find.text('Nicht erlaubt'), findsOneWidget);
    expect(find.textContaining('bricht die Aufzeichnung im Lift ab'), findsOneWidget);

    await tester.ensureVisible(find.text('Standortzugriff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standortzugriff'));
    await tester.pumpAndSettle();
    expect(permissions.openedSettings, 1);
  });

  testWidgets('English locale switches the copy', (tester) async {
    await openSheet(tester, overrides: settingsOverrides(notifier: TestSettings()), locale: const Locale('en'));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Follows the language'), findsOneWidget);
    expect(find.text('Delete all data'), findsOneWidget);
    expect(find.byType(AccountRow), findsOneWidget);
  });
}
