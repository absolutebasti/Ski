import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/settings/settings.dart';
import 'package:slopetrack/features/social/moderation/moderation.dart';
import 'package:slopetrack/features/social/rider/rider.dart';
import 'package:slopetrack/features/social/social_controls.dart' show AvatarCircle;

import '../../support/pump.dart';

const _de = SettingsStrings(AppLocale(Locale('de')));
const _user = AuthUser(id: 'u1', displayName: 'Sebastian', email: 'ski@example.com');
const _lena = RiderProfile(userId: 'u2', displayName: 'Lena Bergmann', seasonKey: '2025/26');
const _lenaBlocked = BlockedRider(userId: 'u2', displayName: 'Lena Bergmann', avatarUrl: 'https://example.invalid/lena.png');
const _max = RiderProfile(userId: 'u4', displayName: 'Max Huber', seasonKey: '2025/26');

/// blocked_riders fails (e.g. 0015 not live yet) while everything else works.
class _NoRpcModerationApi extends FakeModerationApi {
  _NoRpcModerationApi({super.userId, super.blocked});

  @override
  Future<List<BlockedRider>> blockedRiders() async => throw const ModerationError(ModerationErrorKind.failed, 'PGRST202');
}

List<Override> _overrides({required FakeModerationApi mod, FakeRiderApi? rider, AuthUser? user = _user}) => [
      authStateProvider.overrideWith((ref) => Stream<AuthUser?>.value(user)),
      moderationApiProvider.overrideWithValue(mod),
      riderApiProvider.overrideWithValue(rider),
    ];

Future<void> _pump(WidgetTester tester, List<Override> overrides, {Locale locale = const Locale('de')}) async {
  await pumpApp(tester, const BlockedUsersPage(), overrides: overrides, locale: locale);
  await tester.pumpAndSettle();
}

/// riderName's fallback under de (SOC-NAME-FALLBACK).
const _fallbackDe = 'Skifahrer';

Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('names come from blocked_riders; rider_profile is not asked when the RPC knows the rider', (tester) async {
    final mod = FakeModerationApi(userId: 'u1', blocked: const {'u3', 'u2'}, riders: const {'u2': _lenaBlocked});
    final rider = FakeRiderApi();
    await _pump(tester, _overrides(mod: mod, rider: rider));

    expect(find.text(_de.blockedUsers), findsOneWidget);
    expect(find.byType(BlockedRow), findsNWidgets(2));
    expect(find.text('Lena Bergmann'), findsOneWidget, reason: 'blocked_riders resolves names although rider_profile hides blocked pairs');
    final lenaAvatar = tester.widget<AvatarCircle>(find.descendant(of: find.byKey(const ValueKey('blocked-u2')), matching: find.byType(AvatarCircle)));
    expect(lenaAvatar.avatarUrl, 'https://example.invalid/lena.png');
    expect(find.text(_fallbackDe), findsOneWidget, reason: 'u3 has no profile row');
    expect(rider.calls, ['u3'], reason: 'rider_profile only for the rider blocked_riders could not name');
    expect(find.byKey(const ValueKey('blocked-empty')), findsNothing);
    expect(find.text(_de.unblock), findsNWidgets(2));
  });

  testWidgets('rows are ordered newest block first', (tester) async {
    // insertion order = block order: u2 first, then u4 → u4 is the newest
    final mod = FakeModerationApi(
      userId: 'u1',
      blocked: const {'u2', 'u4'},
      riders: const {'u2': _lenaBlocked, 'u4': BlockedRider(userId: 'u4', displayName: 'Max Huber')},
    );
    await _pump(tester, _overrides(mod: mod, rider: FakeRiderApi()));
    final max = tester.getTopLeft(find.text('Max Huber')).dy;
    final lena = tester.getTopLeft(find.text('Lena Bergmann')).dy;
    expect(max, lessThan(lena));
  });

  testWidgets('blocked_riders failing: names fall back to rider_profile, then to the placeholder', (tester) async {
    final mod = _NoRpcModerationApi(userId: 'u1', blocked: const {'u3', 'u4'});
    await _pump(tester, _overrides(mod: mod, rider: FakeRiderApi(profiles: const {'u4': _max})));
    expect(find.byType(BlockedRow), findsNWidgets(2));
    expect(find.text('Max Huber'), findsOneWidget);
    expect(find.text(_fallbackDe), findsOneWidget);
  });

  testWidgets('"Freigeben" calls the api and removes the row', (tester) async {
    final mod = FakeModerationApi(userId: 'u1', blocked: const {'u2', 'u3'}, riders: const {'u2': _lenaBlocked});
    await _pump(tester, _overrides(mod: mod, rider: FakeRiderApi()));

    final ridersCalls = mod.blockedRidersCalls;
    await tester.tap(find.byKey(const ValueKey('unblock-u2')));
    await tester.pumpAndSettle();

    expect(mod.unblockCalls, ['u2']);
    expect(mod.blocked, {'u3'});
    expect(mod.blockedRidersCalls, greaterThan(ridersCalls), reason: 'unblock refetches blocked_riders too');
    expect(find.byType(BlockedRow), findsOneWidget);
    expect(find.text('Lena Bergmann'), findsNothing);
    expect(find.text(_de.unblockedToast), findsOneWidget);
    await _settleToast(tester);

    await tester.tap(find.byKey(const ValueKey('unblock-u3')));
    await tester.pumpAndSettle();
    expect(mod.unblockCalls, ['u2', 'u3']);
    expect(find.byType(BlockedRow), findsNothing);
    expect(find.text(_de.blockedNone), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('nobody blocked: the empty line', (tester) async {
    await _pump(tester, _overrides(mod: FakeModerationApi(userId: 'u1')));
    expect(find.byKey(const ValueKey('blocked-empty')), findsOneWidget);
    expect(find.text(_de.blockedNone), findsOneWidget);
    expect(find.byType(BlockedRow), findsNothing);
  });

  testWidgets('no names anywhere: rows still render with the fallback name', (tester) async {
    final mod = FakeModerationApi(userId: 'u1', blocked: const {'u2'});
    await _pump(tester, _overrides(mod: mod, rider: null));
    expect(find.byType(BlockedRow), findsOneWidget);
    expect(find.text(_fallbackDe), findsOneWidget);
  });

  testWidgets('the fallback name follows the app language: Skier under en', (tester) async {
    final mod = FakeModerationApi(userId: 'u1', blocked: const {'u2'}, riders: const {'u2': BlockedRider(userId: 'u2')});
    await _pump(tester, _overrides(mod: mod, rider: null), locale: const Locale('en'));
    expect(find.text('Skier'), findsOneWidget);
    expect(find.text(_fallbackDe), findsNothing);
  });

  testWidgets('a failing unblock keeps the row and says so', (tester) async {
    final mod = FakeModerationApi(userId: 'u1', blocked: const {'u2'});
    await _pump(tester, _overrides(mod: mod, rider: FakeRiderApi(profiles: const {'u2': _lena})));
    mod.failWith = const ModerationError(ModerationErrorKind.offline);

    await tester.tap(find.byKey(const ValueKey('unblock-u2')));
    await tester.pumpAndSettle();
    expect(find.text(_de.unblockFailed), findsOneWidget);
    expect(mod.blocked, {'u2'});
    expect(find.byType(BlockedRow), findsOneWidget, reason: 'nothing was unblocked, the list stays');
    await _settleToast(tester);
  });

  testWidgets('English copy', (tester) async {
    await pumpApp(tester, const BlockedUsersPage(), overrides: _overrides(mod: FakeModerationApi(userId: 'u1')), locale: const Locale('en'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked users'), findsOneWidget);
    expect(find.text('Nobody blocked.'), findsOneWidget);
  });
}
