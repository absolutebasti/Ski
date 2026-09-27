import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/rider/rider.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../social_fixtures.dart';
import 'rider_fixtures.dart';

Future<void> _pump(
  WidgetTester tester, {
  required FakeRiderApi rider,
  FakeSocialApi? social,
  ShareRecorder? share,
  RiderActions actions = const RiderActions(),
  String userId = 'u9',
  bool signedIn = true,
  Locale locale = const Locale('de'),
  List<Override> extra = const [],
}) async {
  await pumpApp(
    tester,
    Scaffold(backgroundColor: Colors.transparent, body: Padding(padding: const EdgeInsets.all(20), child: RiderSheetBody(userId: userId))),
    locale: locale,
    overrides: [
      ...screenOverrides(resorts: kResorts),
      ...socialOverrides(api: social ?? FakeSocialApi(userId: 'u1'), user: signedIn ? kUser : null),
      ...riderOverrides(api: rider, share: share, actions: actions),
      ...extra,
    ],
  );
  await tester.pump();
}

void main() {
  testWidgets('renders name, flag, level title, four numerals and the medal count', (tester) async {
    final api = FakeRiderApi(profiles: {'u9': kLena});
    await _pump(tester, rider: api);
    await tester.pumpAndSettle();

    expect(api.calls, ['u9']);
    expect(find.text('Lena Bergmann'), findsOneWidget);
    expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).countryCode, 'AT');
    expect(find.text('Österreich · Kitzbühel'), findsOneWidget);
    expect(find.text('LEVEL 4 · CARVER'), findsOneWidget);
    expect(find.text('SAISON 2025/26'), findsOneWidget);
    // hm · km · Abfahrten · Tage — numerals with units as separate text.
    expect(find.text('12.480'), findsOneWidget);
    expect(find.text('hm'), findsOneWidget);
    expect(find.text('98'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('ABFAHRTEN'), findsOneWidget);
    expect(find.text('SKITAGE'), findsOneWidget);
    expect(find.text('13 / 48 Medaillen'), findsOneWidget);
    expect(find.text('1.500 Pkt.'), findsOneWidget);
    expect(find.text('120 km gesamt'), findsOneWidget);
    expect(find.textContaining('Zuletzt am'), findsOneWidget);
    expect(find.text('Herausfordern'), findsOneWidget);
    expect(find.text('Freund hinzufügen'), findsNothing, reason: 'slot empty until SOC-FRIENDS fills it');
    expect(find.bySemanticsLabel('Profil von Lena Bergmann'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loading shows the skeleton until the profile arrives', (tester) async {
    final api = FakeRiderApi(profiles: {'u9': kLena}, gate: Completer<void>());
    await _pump(tester, rider: api);

    expect(find.byKey(const ValueKey('rider-skeleton')), findsOneWidget);
    expect(find.text('Lena Bergmann'), findsNothing);

    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rider-skeleton')), findsNothing);
    expect(find.text('Lena Bergmann'), findsOneWidget);
  });

  testWidgets('a failed call shows the error state and retry refetches', (tester) async {
    final api = FakeRiderApi(profiles: {'u9': kLena}, failWith: const SocialError(SocialErrorKind.failed));
    await _pump(tester, rider: api);
    await tester.pumpAndSettle();

    expect(find.text('Hat nicht geklappt.'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);

    api.failWith = null;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(api.calls, ['u9', 'u9']);
    expect(find.text('Lena Bergmann'), findsOneWidget);
  });

  testWidgets('offline has its own line; without a backend too', (tester) async {
    await _pump(tester, rider: FakeRiderApi(failWith: const SocialError(SocialErrorKind.offline)));
    await tester.pumpAndSettle();
    expect(find.text('Keine Verbindung.'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets('a private profile is explained, not empty', (tester) async {
    await _pump(tester, rider: FakeRiderApi());
    await tester.pumpAndSettle();
    expect(find.text('Dieses Profil ist privat.'), findsOneWidget);
    expect(find.text('Herausfordern'), findsNothing);
  });

  testWidgets('Herausfordern creates a duel and shares its code addressed to the rider', (tester) async {
    final social = FakeSocialApi(userId: 'u1');
    final share = ShareRecorder();
    await _pump(tester, rider: FakeRiderApi(profiles: {'u9': kLena}), social: social, share: share);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();

    expect(social.created, ['Tagesduell']);
    expect(share.shared, hasLength(1));
    expect(share.shared.single.$1, contains('KMJ4F2'));
    expect(share.shared.single.$1, contains('Lena Bergmann'));
    expect(share.shared.single.$2, 'Tagesduell');
  });

  testWidgets('Herausfordern reuses the duel of the day instead of creating a second one', (tester) async {
    final social = FakeSocialApi(userId: 'u1', duel: duelGroup(code: 'PQRS23'));
    final share = ShareRecorder();
    await _pump(tester, rider: FakeRiderApi(profiles: {'u9': kLena}), social: social, share: share);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();

    expect(social.created, isEmpty);
    expect(share.shared.single.$1, contains('PQRS23'));
  });

  testWidgets('signed out, Herausfordern asks for an account and shares nothing', (tester) async {
    final share = ShareRecorder();
    await _pump(tester, rider: FakeRiderApi(profiles: {'u9': kLena}), social: FakeSocialApi(), share: share, signedIn: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();
    expect(find.text('Dafür brauchst du ein Konto'), findsOneWidget);
    expect(share.shared, isEmpty);
  });

  testWidgets('the own profile has no challenge button', (tester) async {
    const me = RiderProfile(userId: 'u1', displayName: 'Sebastian Fackelmann', seasonKey: '2025/26');
    await _pump(tester, rider: FakeRiderApi(profiles: {'u1': me}), userId: 'u1');
    await tester.pumpAndSettle();
    expect(find.text('Sebastian Fackelmann'), findsOneWidget);
    expect(find.text('LEVEL 1 · ROOKIE'), findsOneWidget);
    expect(find.text('0 / 48 Medaillen'), findsOneWidget);
    expect(find.text('Noch kein Skitag'), findsOneWidget);
    expect(find.text('Herausfordern'), findsNothing);
  });

  testWidgets('the actions slot renders and calls the handlers a later package provides', (tester) async {
    final calls = <String>[];
    final actions = RiderActions(
      addFriend: (_, rider) async => calls.add('friend:${rider.userId}'),
      report: (_, rider) async => calls.add('report:${rider.userId}'),
      block: (_, rider) async => calls.add('block:${rider.userId}'),
    );
    await _pump(tester, rider: FakeRiderApi(profiles: {'u9': kLena}), actions: actions);
    await tester.pumpAndSettle();

    expect(find.text('Freund hinzufügen'), findsOneWidget);
    expect(find.text('Melden'), findsOneWidget);
    expect(find.text('Blockieren'), findsOneWidget);

    await tester.tap(find.text('Freund hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Melden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blockieren'));
    await tester.pumpAndSettle();
    expect(calls, ['friend:u9', 'report:u9', 'block:u9']);
  });

  testWidgets('English copy', (tester) async {
    await _pump(tester, rider: FakeRiderApi(profiles: {'u9': kLena}), locale: const Locale('en'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Profile of Lena Bergmann'), findsOneWidget);
    expect(find.text('LEVEL 4 · CARVER'), findsOneWidget);
    expect(find.text('SEASON 2025/26'), findsOneWidget);
    expect(find.text('13 / 48 medals'), findsOneWidget);
    expect(find.text('Austria · Kitzbühel'), findsOneWidget);
    expect(find.text('Challenge'), findsOneWidget);
    expect(find.text('m'), findsOneWidget, reason: 'vertical unit is m in English');
  });

  testWidgets('RiderSheet.show opens the sheet with title and profile', (tester) async {
    await pumpApp(
      tester,
      Builder(builder: (context) => Center(child: TextButton(onPressed: () => RiderSheet.show(context, 'u9'), child: const Text('open')))),
      overrides: [
        ...screenOverrides(resorts: kResorts),
        ...socialOverrides(api: FakeSocialApi(userId: 'u1'), user: kUser),
        ...riderOverrides(api: FakeRiderApi(profiles: {'u9': kLena})),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Lena Bergmann'), findsOneWidget);
    expect(find.text('LEVEL 4 · CARVER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
