import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/brand.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/data/resorts/resort_repository.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/data/sync/sync_service.dart';
import 'package:slopetrack/features/account/account.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';
import 'package:slopetrack/features/social/country_card.dart';
import 'package:slopetrack/features/social/friends/friends.dart';
import 'package:slopetrack/features/social/social_controls.dart';
import 'package:slopetrack/features/social/social_models.dart';
import 'package:slopetrack/features/today/season_goal_sheet.dart';

import '../../support/pump.dart';
import '../achievements/ui/achievements_fixtures.dart';

const _de = AccountStrings(AppLocale(Locale('de')));
const _user = AuthUser(id: 'u1', displayName: 'Sebastian', email: 'ski@example.com');

const _resorts = [
  Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.44, lon: 12.39, radiusKm: 12),
  Resort(id: 'ischgl', name: 'Ischgl', country: 'AT', lat: 47.01, lon: 10.29, radiusKm: 10),
];

final _thisSeason = seasonKey(DateTime.now());

/// Everything the page touches, faked: no Supabase, no database, no plugins.
List<Override> _overrides({
  AuthUser? user = _user,
  Stream<AuthUser?>? authStream,
  AccountAction? signOut,
  FakeProfileApi? api,
  String? country = 'AT',
  FakeAvatarPicker? picker,
  List<Uri>? opened,
  List<SeasonTotals>? seasons,
  bool available = true,
  SignInAction? signIn,
  DeleteAccountAction? delete,
  SyncTrigger? sync,
  Settings? settings,
  SyncStatus syncStatus = const SyncStatus(),
}) =>
    [
      accountAvailableProvider.overrideWithValue(available),
      authStateProvider.overrideWith((ref) => authStream ?? Stream<AuthUser?>.value(user)),
      profileApiProvider.overrideWithValue(api),
      resortRepositoryProvider.overrideWith((ref) async => ResortRepository(_resorts)),
      accountSyncStatusProvider.overrideWith((ref) => Stream<SyncStatus>.value(syncStatus)),
      accountSyncTriggerProvider.overrideWithValue(sync ?? () async {}),
      accountSignInProvider.overrideWithValue(signIn ?? () async => _user),
      accountSignOutProvider.overrideWithValue(signOut ?? () async {}),
      accountDeleteProvider.overrideWithValue(delete ?? () async => true),
      settingsProvider.overrideWith(() => SettingsNotifier(null, initial: settings ?? Settings(onboardingDone: true, countryCode: country))),
      seasonTotalsProvider.overrideWith(
        (ref) => Stream.value(seasons ?? [SeasonTotals(seasonKey: _thisSeason, dayCount: 3, runCount: 21, dropM: 5717, skiDistanceM: 61000, maxSpeedMs: 69 / 3.6)]),
      ),
      friendsApiProvider.overrideWithValue(FakeFriendsApi(userId: user?.id, code: 'KMJ4F2')),
      avatarPickerProvider.overrideWithValue(picker),
      accountOpenUriProvider.overrideWithValue((uri) async => opened?.add(uri)),
      ...achievementsOverrides(fixtureAchievements()),
    ];

Future<void> _pumpPage(WidgetTester tester, List<Override> overrides) async {
  await pumpApp(tester, const ProfilePage(), overrides: overrides);
  await tester.pumpAndSettle();
}

Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

FakeProfileApi _api({String? avatar, String country = 'AT'}) => FakeProfileApi(userId: 'u1', row: {
      'id': 'u1',
      'display_name': 'Sebastian',
      'home_resort_id': 'kitzbuehel',
      'share_leaderboards': true,
      'country_code': country,
      'avatar_url': avatar,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed in: avatar initials, name, team with "Team ändern", home resort, level, medals, season, friend code', (tester) async {
    await _pumpPage(tester, _overrides(api: _api()));

    expect(find.byKey(const ValueKey('profile-signed-in')), findsOneWidget);
    // Avatar without a picture → initials.
    expect(find.byKey(const ValueKey('profile-avatar')), findsOneWidget);
    expect(find.text(initialsOf('Sebastian')), findsWidgets);
    expect(find.byType(Image), findsNothing);
    // Name in the field.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('profile-name-field'))).controller!.text, 'Sebastian');
    expect(find.byKey(const ValueKey('profile-name-save')), findsNothing, reason: 'nothing to save yet');
    // Team.
    expect(find.text('Österreich'), findsOneWidget);
    expect(find.text(_de.changeTeam), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
    // Home resort.
    expect(find.text('Kitzbühel'), findsOneWidget);

    await _scrollTo(tester, find.byKey(const ValueKey('profile-level')));
    expect(find.byType(LevelRing), findsOneWidget);
    expect(find.text('7 / 48 Medaillen'), findsOneWidget);
    expect(find.byType(StreakChip), findsOneWidget);

    await _scrollTo(tester, find.byKey(const ValueKey('profile-season')));
    expect(find.text('Saison $_thisSeason'.toUpperCase()), findsOneWidget);
    expect(find.text('5.717'), findsOneWidget, reason: 'season vertical');
    expect(find.text('61'), findsOneWidget, reason: 'season ski km');
    expect(find.text('69'), findsOneWidget, reason: 'season top speed');
    expect(find.text('312'), findsOneWidget, reason: 'lifetime km from achievements');
    expect(find.text('12'), findsOneWidget, reason: 'lifetime days');

    await _scrollTo(tester, find.byKey(const ValueKey('profile-friend-code')));
    expect(find.text('KMJ4F2'), findsOneWidget);
    expect(find.text(_de.friends), findsWidgets);

    await _scrollTo(tester, find.byKey(const ValueKey('profile-contact')));
    expect(find.text(kSupportEmail), findsOneWidget);
    await _scrollTo(tester, find.byKey(const ValueKey('account-delete')));
    expect(find.byKey(const ValueKey('account-sign-out')), findsOneWidget);
  });

  testWidgets('signed out: rider line, three benefits, Apple button, "Ohne Konto weiter", level card and season goal', (tester) async {
    var signIns = 0;
    await _pumpPage(tester, _overrides(user: null, signIn: () async {
      signIns++;
      return null;
    }));
    expect(find.byKey(const ValueKey('account-signed-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-signed-in')), findsNothing);
    expect(find.text(_de.signedOutLine), findsOneWidget);
    // Three benefit rows in order.
    expect(find.byKey(const ValueKey('account-benefit-backup')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-benefit-boards')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-benefit-friends')), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Ranglisten & Duelle'), findsOneWidget);
    expect(find.text('Freunde'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('account-benefit-backup'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('account-benefit-boards'))).dy),
    );
    // Apple button and the secondary way out.
    expect(find.byKey(const ValueKey('account-apple')), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);
    expect(find.text(_de.signInWithApple), findsOneWidget);
    expect(find.byKey(const ValueKey('account-continue')), findsOneWidget);
    expect(find.text('Ohne Konto weiter'), findsOneWidget);
    // Device-computed level card and the goal row fill the lower half.
    await _scrollTo(tester, find.byKey(const ValueKey('profile-level')));
    expect(find.byType(LevelRing), findsOneWidget);
    expect(find.text('7 / 48 Medaillen'), findsOneWidget);
    expect(find.text(_de.deviceLevelHint), findsOneWidget);
    await _scrollTo(tester, find.byKey(const ValueKey('profile-season-goal')));
    expect(find.text(_de.seasonGoal), findsOneWidget);
    expect(find.text('20.000'), findsOneWidget, reason: 'default goal');
    // No sign-in yet.
    expect(signIns, 0);
    await _scrollTo(tester, find.byKey(const ValueKey('account-apple')));
    await tester.tap(find.byKey(const ValueKey('account-apple')));
    await tester.pumpAndSettle();
    expect(signIns, 1);
    expect(find.text(_de.signInFailed), findsOneWidget, reason: 'null user = failed');
  });

  testWidgets('signed out without a backend: the Apple button is disabled and the page explains', (tester) async {
    var signIns = 0;
    await _pumpPage(tester, _overrides(user: null, available: false, signIn: () async {
      signIns++;
      return _user;
    }));
    expect(find.text(_de.unavailable), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-apple')));
    await tester.pumpAndSettle();
    expect(signIns, 0);
    expect(find.byKey(const ValueKey('account-continue')), findsOneWidget, reason: 'the way out stays');
  });

  testWidgets('"Ohne Konto weiter" pops the page', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(child: TextButton(onPressed: () => ProfilePage.open(context), child: const Text('open'))),
        ),
      ),
      overrides: _overrides(user: null),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the Apple button uses the onboarding look: ink fill in dark, hairline border', (tester) async {
    await _pumpPage(tester, _overrides(user: null));
    // The shared AppleButton (app/widgets/buttons.dart) under the account key.
    final box = tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(const ValueKey('account-apple')), matching: find.byType(AnimatedContainer)));
    final deco = box.decoration! as BoxDecoration;
    expect(deco.border, isNotNull);
    expect(deco.color, const Color(0xFF07070A), reason: 'AppColors.ink in the dark theme');
  });

  testWidgets('Saisonziel row opens the goal sheet and persists 25.000', (tester) async {
    await _pumpPage(tester, _overrides(api: _api()));
    await _scrollTo(tester, find.byKey(const ValueKey('profile-season-goal')));
    expect(find.text('20.000'), findsOneWidget);

    await tester.tap(find.text(_de.seasonGoal));
    await tester.pumpAndSettle();
    expect(find.byType(SeasonGoalSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('season-goal-value')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('season-goal-save')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(ProfilePageBody)));
    expect(container.read(settingsProvider).seasonGoalHm, 25000);
    expect(find.byType(SeasonGoalSheet), findsNothing);
    expect(find.text('25.000'), findsOneWidget, reason: 'the row follows the setting');
  });

  testWidgets('"Kein Ziel" shows in the row when the goal is 0', (tester) async {
    await _pumpPage(tester, _overrides(api: _api(), settings: const Settings(onboardingDone: true, countryCode: 'AT', seasonGoalHm: 0)));
    await _scrollTo(tester, find.byKey(const ValueKey('profile-season-goal')));
    expect(find.text(_de.seasonGoalNone), findsOneWidget);
  });

  testWidgets('"Jetzt synchronisieren" triggers a sync', (tester) async {
    var syncs = 0;
    await _pumpPage(tester, _overrides(api: _api(), sync: () async => syncs++));
    await _scrollTo(tester, find.byKey(const ValueKey('account-sync-now')));
    await tester.tap(find.byKey(const ValueKey('account-sync-now')));
    await tester.pumpAndSettle();
    expect(syncs, 1);
  });

  testWidgets('deleting the account needs both confirmations', (tester) async {
    var deletes = 0;
    await _pumpPage(tester, _overrides(api: _api(), delete: () async {
      deletes++;
      return true;
    }));

    await _scrollTo(tester, find.byKey(const ValueKey('account-delete')));
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    expect(find.text(_de.deleteTitle), findsOneWidget);

    // Backing out of the first sheet deletes nothing.
    await tester.tap(find.byKey(const ValueKey('account-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(deletes, 0);

    await _scrollTo(tester, find.byKey(const ValueKey('account-delete')));
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
    expect(find.text(_de.deletedToast), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('a failed deletion says so, keeps the profile and shows no "Konto gelöscht"', (tester) async {
    var deletes = 0;
    final api = _api();
    await _pumpPage(tester, _overrides(api: api, delete: () async {
      deletes++;
      return false;
    }));

    await _scrollTo(tester, find.byKey(const ValueKey('account-delete')));
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete-1')));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('account-delete-2'))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(deletes, 1);
    expect(find.text('Löschen hat nicht geklappt, bitte später erneut'), findsOneWidget);
    expect(find.text(_de.deletedToast), findsNothing);
    expect(find.byKey(const ValueKey('profile-signed-in')), findsOneWidget, reason: 'the session stays');
    final container = ProviderScope.containerOf(tester.element(find.byType(ProfilePageBody)));
    expect(container.read(profileServiceProvider).cached?.displayName, 'Sebastian', reason: 'the cached profile is not dropped');
    await _settleToast(tester);
  });

  testWidgets('a rate-limited sync reads "Sync pausiert, geht gleich weiter", never offline', (tester) async {
    await _pumpPage(tester, _overrides(api: _api(), syncStatus: const SyncStatus(state: SyncState.throttled, pending: 2)));
    await _scrollTo(tester, find.byKey(const ValueKey('account-sync-line')));
    expect(tester.widget<Text>(find.byKey(const ValueKey('account-sync-line'))).data, 'Sync pausiert, geht gleich weiter');
    expect(find.text(_de.syncOffline), findsNothing);
  });

  testWidgets('changing the team writes the setting and the profile; the flag updates', (tester) async {
    final api = _api();
    await _pumpPage(tester, _overrides(api: api));
    expect(api.patches, isEmpty, reason: 'setting AT and server AT agree');

    await tester.tap(find.byKey(const ValueKey('profile-team-change')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('country-CH')), findsOneWidget);
    expect(find.text('Schweiz'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('country-CH')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(ProfilePageBody)));
    expect(container.read(settingsProvider).countryCode, 'CH');
    expect(api.patches.where((p) => p['country_code'] == 'CH'), hasLength(1));
    expect(api.row?['country_code'], 'CH');
    expect(find.text('Schweiz'), findsOneWidget);
    expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).countryCode, 'CH');
    await _settleToast(tester);
  });

  testWidgets('name field is capped at 24 characters', (tester) async {
    final api = _api();
    await _pumpPage(tester, _overrides(api: api));

    final field = find.byKey(const ValueKey('profile-name-field'));
    expect(tester.widget<TextField>(field).maxLength, 24);
    await tester.enterText(field, 'Sebastian Fackelmann der Dritte'); // 31 chars
    await tester.pumpAndSettle();
    final text = tester.widget<TextField>(field).controller!.text;
    expect(text.length, 24);
    expect(text, 'Sebastian Fackelmann der');
  });

  testWidgets('a rejected name shows the inline hint and does not write', (tester) async {
    final api = _api();
    await _pumpPage(tester, _overrides(api: api));

    final field = find.byKey(const ValueKey('profile-name-field'));
    await tester.enterText(field, 'Admin');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-name-save')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-name-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-name-hint')), findsOneWidget);
    expect(find.text('Dieser Name geht nicht. Wähl einen anderen.'), findsOneWidget);
    expect(api.patches, isEmpty);

    // A good name saves, normalised.
    await tester.enterText(field, '  Basti   F. ');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-name-hint')), findsNothing, reason: 'typing clears the hint');
    await tester.tap(find.byKey(const ValueKey('profile-name-save')));
    await tester.pumpAndSettle();
    expect(api.patches, [
      {'display_name': 'Basti F.'},
    ]);
    expect(find.byKey(const ValueKey('profile-name-save')), findsNothing);
    await _settleToast(tester);
  });

  testWidgets('picking an avatar uploads to avatars/<uid>/avatar.jpg and renders the network image', (tester) async {
    final api = _api();
    final picker = FakeAvatarPicker(result: PickedAvatar(Uint8List.fromList([1, 2, 3])));
    await _pumpPage(tester, _overrides(api: api, picker: picker));
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(api.uploads, hasLength(1));
    expect(api.uploads.single.path, 'u1/avatar.jpg');
    expect(api.uploads.single.contentType, 'image/jpeg');
    expect(api.uploads.single.bytes, [1, 2, 3]);
    final url = '${FakeProfileApi.publicBase}u1/avatar.jpg';
    expect(api.row?['avatar_url'], url);
    expect(api.patches.last, {'avatar_url': url});

    final avatar = tester.widget<AvatarCircle>(find.descendant(of: find.byKey(const ValueKey('profile-avatar')), matching: find.byType(AvatarCircle)));
    expect(avatar.avatarUrl, url);
    final image = tester.widget<Image>(find.descendant(of: find.byKey(const ValueKey('profile-avatar')), matching: find.byType(Image)));
    expect((image.image as NetworkImage).url, url);
    await _settleToast(tester);
  });

  testWidgets('a cancelled pick and a missing picker change nothing', (tester) async {
    final api = _api();
    final picker = FakeAvatarPicker();
    await _pumpPage(tester, _overrides(api: api, picker: picker));
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    expect(picker.calls, 1);
    expect(api.uploads, isEmpty);
    expect(api.patches, isEmpty);
  });

  testWidgets('without a picker the tap explains instead of failing', (tester) async {
    final api = _api();
    await _pumpPage(tester, _overrides(api: api));
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    expect(find.text(_de.photoUnavailable), findsOneWidget);
    expect(api.uploads, isEmpty);
    await _settleToast(tester);
  });

  testWidgets('a stored avatar_url renders as the network image on load', (tester) async {
    const url = 'https://example.test/u1/avatar.jpg';
    await _pumpPage(tester, _overrides(api: _api(avatar: url)));
    final image = tester.widget<Image>(find.descendant(of: find.byKey(const ValueKey('profile-avatar')), matching: find.byType(Image)));
    expect((image.image as NetworkImage).url, url);
  });

  testWidgets('"Freunde" opens the friends sheet, the level card opens the medals sheet', (tester) async {
    await _pumpPage(tester, _overrides(api: _api()));

    await _scrollTo(tester, find.byKey(const ValueKey('profile-friends')));
    await tester.tap(find.byKey(const ValueKey('profile-friends')));
    await tester.pumpAndSettle();
    expect(find.byType(FriendsSheetBody), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();
    expect(find.byType(FriendsSheetBody), findsNothing);

    await _scrollTo(tester, find.byKey(const ValueKey('profile-level')));
    await tester.tap(find.byType(LevelRing));
    await tester.pumpAndSettle();
    expect(find.byType(MedalsSheetBody), findsOneWidget);
  });

  testWidgets('contact row opens a mailto to the support address', (tester) async {
    final opened = <Uri>[];
    await _pumpPage(tester, _overrides(api: _api(), opened: opened));
    await _scrollTo(tester, find.byKey(const ValueKey('profile-contact')));
    await tester.tap(find.byKey(const ValueKey('profile-contact')));
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(opened.single.scheme, 'mailto');
    expect(opened.single.path, kSupportEmail);
    expect(opened.single.queryParameters['subject'], _de.mailSubject);
  });

  testWidgets('opt-in switch, home resort picker and sign-out work on the page', (tester) async {
    final auth = StreamController<AuthUser?>();
    addTearDown(auth.close);
    var signOuts = 0;
    final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian', 'country_code': 'AT'});
    await _pumpPage(tester, _overrides(
      api: api,
      authStream: auth.stream,
      signOut: () async {
        signOuts++;
        auth.add(null);
      },
    ));
    auth.add(_user);
    await tester.pumpAndSettle();

    expect(find.text(_de.noResort), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-resort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resort-ischgl')));
    await tester.pumpAndSettle();
    expect(api.patches.last, {'home_resort_id': 'ischgl'});
    expect(find.text('Ischgl'), findsOneWidget);

    await _scrollTo(tester, find.byKey(const ValueKey('account-share-switch')));
    await tester.tap(find.byKey(const ValueKey('account-share-switch')));
    await tester.pumpAndSettle();
    expect(api.patches.last, {'share_leaderboards': true});

    await _scrollTo(tester, find.byKey(const ValueKey('account-sign-out')));
    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(ProfilePageBody)));
    expect(signOuts, 1);
    expect(container.read(profileServiceProvider).cached, isNull);
    expect(find.byKey(const ValueKey('account-signed-out')), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('country picker lists the grid countries first, then the rest by name', (tester) async {
    await pumpApp(tester, const Scaffold(body: CountryPickerBody(selected: 'DE')));
    await tester.pumpAndSettle();
    final entries = CountryPickerSheet.entries(const AppLocale(Locale('de')));
    expect(entries.take(5).map((e) => e.code), ['AT', 'CH', 'DE', 'IT', 'FR']);
    expect(entries[5].de, 'Andorra');
    expect(entries.length, 39);
    expect(find.byKey(const ValueKey('country-AT')), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'DE is marked');
  });
}
