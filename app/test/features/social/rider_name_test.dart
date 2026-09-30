import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/data/sync/profile_repair.dart' show kFallbackDisplayName;
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../support/pump.dart';
import '../../support/screen_overrides.dart';
import 'rider/rider_fixtures.dart';
import 'social_fixtures.dart';

const _de = AppLocale(Locale('de'));
const _en = AppLocale(Locale('en'));

/// SOC-NAME-FALLBACK: models keep display_name nullable, the UI resolves
/// 'Skifahrer' / 'Skier' per app locale.
void main() {
  group('riderNameFor', () {
    test('null, blank and the server default resolve per locale', () {
      for (final raw in [null, '', '   ', '\t\n', kFallbackDisplayName, ' $kFallbackDisplayName ']) {
        expect(riderNameFor(_de, raw), 'Skifahrer', reason: '"$raw"');
        expect(riderNameFor(_en, raw), 'Skier', reason: '"$raw"');
      }
    });

    test('a real name comes back trimmed in both languages', () {
      expect(riderNameFor(_de, ' Lena Bergmann '), 'Lena Bergmann');
      expect(riderNameFor(_en, 'Lena Bergmann'), 'Lena Bergmann');
      expect(riderNameFor(_en, 'Skifahrerin'), 'Skifahrerin', reason: 'only the exact server default counts as no name');
    });

    test('parseDisplayName folds blank and non-strings to null', () {
      expect(parseDisplayName(null), isNull);
      expect(parseDisplayName(''), isNull);
      expect(parseDisplayName('  '), isNull);
      expect(parseDisplayName(42), isNull);
      expect(parseDisplayName(' Nina '), 'Nina');
    });

    test('every row parser keeps a missing name as null', () {
      expect(LeaderboardEntry.fromJson(const {'rank': 1, 'user_id': 'u1', 'display_name': null, 'value': 1}).displayName, isNull);
      expect(LeaderboardEntry.fromJson(const {'rank': 1, 'user_id': 'u1', 'display_name': '  ', 'value': 1}).displayName, isNull);
      expect(RiderProfile.fromJson(const {'user_id': 'u1'}).displayName, isNull);
      expect(Friend.fromJson(const {'user_id': 'u1', 'display_name': ' '}).displayName, isNull);
      expect(ChallengeBoardEntry.fromJson(const {'rank': 1, 'user_id': 'u1'}).displayName, isNull);
      expect(BlockedRider.fromRow(const {'user_id': 'u1'})?.displayName, isNull);
      // Still a String for the duel widgets (another session) — '' = no name.
      expect(GroupMemberStats.fromJson(const {'user_id': 'u1'}).displayName, '');
    });
  });

  group('leaderboard', () {
    final nameless = LeaderboardEntry.fromJson(const {'rank': 4, 'user_id': 'u4', 'display_name': null, 'value': 1200});

    for (final (locale, expected) in [(const Locale('de'), 'Skifahrer'), (const Locale('en'), 'Skier')]) {
      testWidgets('a null display_name renders $expected in a row (${locale.languageCode})', (tester) async {
        await pumpApp(
          tester,
          Scaffold(body: LeaderboardRow(entry: nameless, metric: SocialMetric.dropM, leaderValue: 2000, onTap: () {})),
          locale: locale,
        );
        expect(find.text(expected), findsOneWidget);
        expect(find.text('S'), findsOneWidget, reason: 'avatar initials come from the resolved name');
        expect(find.bySemanticsLabel(RegExp('^4\\. .*$expected')), findsOneWidget);
      });

      testWidgets('a null display_name renders $expected on the podium (${locale.languageCode})', (tester) async {
        final top = [
          const LeaderboardEntry(rank: 1, userId: 'u1', displayName: 'Lena', value: 3000),
          const LeaderboardEntry(rank: 2, userId: 'u2', displayName: null, value: 2000),
        ];
        await pumpApp(tester, Scaffold(body: LeaderboardPodium(entries: top, metric: SocialMetric.dropM, onRider: (_, _) {})), locale: locale);
        expect(find.text(expected), findsOneWidget);
        expect(find.text('Lena'), findsOneWidget);
      });

      testWidgets('a null display_name renders $expected in a challenge row (${locale.languageCode})', (tester) async {
        final entry = ChallengeBoardEntry.fromJson(const {'rank': 2, 'user_id': 'u2', 'value': 800});
        await pumpApp(tester, Scaffold(body: ChallengeBoardRow(entry: entry, metric: SocialMetric.dropM)), locale: locale);
        expect(find.text(expected), findsOneWidget);
      });
    }
  });

  group('rider sheet', () {
    final nameless = RiderProfile.fromJson({...kLenaJson, 'display_name': null});

    for (final (locale, expected, label) in [
      (const Locale('de'), 'Skifahrer', 'Profil von Skifahrer'),
      (const Locale('en'), 'Skier', 'Profile of Skier'),
    ]) {
      testWidgets('a null display_name renders $expected (${locale.languageCode})', (tester) async {
        tester.view.physicalSize = const Size(1179, 3200);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await pumpApp(
          tester,
          const Scaffold(backgroundColor: Colors.transparent, body: Padding(padding: EdgeInsets.all(20), child: RiderSheetBody(userId: 'u9'))),
          locale: locale,
          overrides: [
            ...screenOverrides(resorts: kResorts),
            ...socialOverrides(api: FakeSocialApi(userId: 'u1'), user: kUser),
            ...riderOverrides(api: FakeRiderApi(profiles: {'u9': nameless}), actions: const RiderActions()),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(find.bySemanticsLabel(label), findsOneWidget);
      });
    }
  });
}
