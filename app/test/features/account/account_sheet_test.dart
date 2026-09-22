import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/app/l10n/app_locale.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/data/resorts/resort_repository.dart';
import 'package:dropline/data/sync/auth_service.dart';
import 'package:dropline/data/sync/sync_service.dart';
import 'package:dropline/features/account/account.dart';

import '../../support/pump.dart';

const _de = AccountStrings(AppLocale(Locale('de')));

const _user = AuthUser(id: 'u1', displayName: 'Sebastian', email: 'ski@example.com');

const _resorts = [
  Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.44, lon: 12.39, radiusKm: 12),
  Resort(id: 'ischgl', name: 'Ischgl', country: 'AT', lat: 47.01, lon: 10.29, radiusKm: 10),
];

/// Everything the Konto sheet touches, faked: no Supabase, no database.
List<Override> _overrides({
  bool available = true,
  AuthUser? user,
  Stream<AuthUser?>? authStream,
  FakeProfileApi? api,
  SyncStatus status = const SyncStatus(),
  SignInAction? signIn,
  AccountAction? signOut,
  AccountAction? delete,
  SyncTrigger? sync,
}) =>
    [
      accountAvailableProvider.overrideWithValue(available),
      authStateProvider.overrideWith((ref) => authStream ?? Stream<AuthUser?>.value(user)),
      profileApiProvider.overrideWithValue(api),
      resortRepositoryProvider.overrideWith((ref) async => ResortRepository(_resorts)),
      accountSyncStatusProvider.overrideWith((ref) => Stream<SyncStatus>.value(status)),
      accountSyncTriggerProvider.overrideWithValue(sync ?? () async {}),
      accountSignInProvider.overrideWithValue(signIn ?? () async => null),
      accountSignOutProvider.overrideWithValue(signOut ?? () async {}),
      accountDeleteProvider.overrideWithValue(delete ?? () async {}),
    ];

Future<void> _pumpSheet(WidgetTester tester, List<Override> overrides) async {
  await pumpApp(tester, const Scaffold(body: AccountSheetBody()), overrides: overrides);
  await tester.pumpAndSettle();
}

/// Lets the floating toast expire so no timer outlives the test.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed out: Leo, one sentence and the Apple button', (tester) async {
    var calls = 0;
    await _pumpSheet(tester, _overrides(signIn: () async {
      calls++;
      return _user;
    }));

    expect(find.byKey(const ValueKey('account-signed-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-signed-in')), findsNothing);
    expect(find.text(_de.signedOutLine), findsOneWidget);
    expect(find.text(_de.signInWithApple), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-apple')));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('signed out without a backend: the Apple button is disabled', (tester) async {
    var calls = 0;
    await _pumpSheet(tester, _overrides(available: false, signIn: () async {
      calls++;
      return _user;
    }));

    expect(find.text(_de.unavailable), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-apple')));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('signed in: name, home resort, opt-in, sync line and the actions', (tester) async {
    final api = FakeProfileApi(userId: 'u1', row: {
      'id': 'u1',
      'display_name': 'Sebastian',
      'home_resort_id': 'kitzbuehel',
      'share_leaderboards': true,
    });
    await _pumpSheet(tester, _overrides(
      user: _user,
      api: api,
      status: const SyncStatus(lastSyncAt: 1758528120000, pending: 3),
    ));

    expect(find.byKey(const ValueKey('account-signed-in')), findsOneWidget);
    expect(find.text('Sebastian'), findsOneWidget);
    expect(find.text('Kitzbühel'), findsOneWidget);
    expect(find.text(_de.share), findsOneWidget);
    expect(find.text(_de.shareHint), findsOneWidget);
    expect(tester.widget<Switch>(find.byKey(const ValueKey('account-share-switch'))).value, isTrue);
    expect(find.textContaining('3 ausstehend'), findsOneWidget);
    expect(find.text(_de.syncNow), findsOneWidget);
    expect(find.text(_de.signOut), findsOneWidget);
    expect(find.text(_de.deleteAccount), findsOneWidget);
  });

  testWidgets('signed in without a synced row yet: never-synced line and the auth name', (tester) async {
    await _pumpSheet(tester, _overrides(user: _user, api: FakeProfileApi(userId: 'u1')));
    expect(find.text('Sebastian'), findsOneWidget, reason: 'falls back to the Apple display name');
    expect(find.text(_de.neverSynced), findsOneWidget);
    expect(find.text(_de.noResort), findsOneWidget);
  });

  testWidgets('toggling "In Ranglisten erscheinen" writes share_leaderboards', (tester) async {
    final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'});
    await _pumpSheet(tester, _overrides(user: _user, api: api));

    expect(tester.widget<Switch>(find.byKey(const ValueKey('account-share-switch'))).value, isFalse);
    await tester.tap(find.byKey(const ValueKey('account-share-switch')));
    await tester.pumpAndSettle();

    expect(api.patches, [
      {'share_leaderboards': true},
    ]);
    expect(tester.widget<Switch>(find.byKey(const ValueKey('account-share-switch'))).value, isTrue);
  });

  testWidgets('editing the display name persists it and shows the new name', (tester) async {
    final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'});
    await _pumpSheet(tester, _overrides(user: _user, api: api));

    await tester.tap(find.byKey(const ValueKey('account-name-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('account-name-field')), 'Basti');
    await tester.tap(find.byKey(const ValueKey('account-name-save')));
    await tester.pumpAndSettle();

    expect(api.patches, [
      {'display_name': 'Basti'},
    ]);
    expect(find.text('Basti'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-name-field')), findsNothing);
    await _settleToast(tester);
  });

  testWidgets('"Jetzt synchronisieren" triggers a sync', (tester) async {
    var syncs = 0;
    await _pumpSheet(tester, _overrides(
      user: _user,
      api: FakeProfileApi(userId: 'u1'),
      sync: () async => syncs++,
    ));

    await tester.tap(find.byKey(const ValueKey('account-sync-now')));
    await tester.pumpAndSettle();
    expect(syncs, 1);
  });

  testWidgets('deleting the account needs both confirmations', (tester) async {
    var deletes = 0;
    await _pumpSheet(tester, _overrides(
      user: _user,
      api: FakeProfileApi(userId: 'u1'),
      delete: () async => deletes++,
    ));

    await tester.ensureVisible(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    expect(find.text(_de.deleteTitle), findsOneWidget);

    // Backing out of the first sheet deletes nothing.
    await tester.tap(find.byKey(const ValueKey('account-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(deletes, 0);

    await tester.ensureVisible(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete-1')));
    await tester.pumpAndSettle();
    expect(find.text(_de.deleteConfirmTitle), findsOneWidget);
    expect(deletes, 0, reason: 'the second confirmation is a hold');

    final hold = find.byKey(const ValueKey('account-delete-2'));
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(deletes, 1);
    await _settleToast(tester);
  });

  testWidgets('signing out drops the profile and returns to the signed-out view', (tester) async {
    final auth = StreamController<AuthUser?>();
    addTearDown(auth.close);
    var signOuts = 0;
    final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'});
    await _pumpSheet(tester, _overrides(
      authStream: auth.stream,
      api: api,
      signOut: () async {
        signOuts++;
        auth.add(null);
      },
    ));
    auth.add(_user);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(AccountSheetBody)));
    expect(container.read(profileServiceProvider).cached, isNotNull);

    await tester.ensureVisible(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
    expect(container.read(profileServiceProvider).cached, isNull);
    expect(find.byKey(const ValueKey('account-signed-out')), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('home resort picker is searchable and writes the choice', (tester) async {
    final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'});
    await _pumpSheet(tester, _overrides(user: _user, api: api));

    await tester.tap(find.byKey(const ValueKey('account-resort')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resort-ischgl')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('resort-search')), 'kitz');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resort-ischgl')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('resort-kitzbuehel')));
    await tester.pumpAndSettle();
    expect(api.patches, [
      {'home_resort_id': 'kitzbuehel'},
    ]);
    expect(find.text('Kitzbühel'), findsOneWidget);
  });
}
