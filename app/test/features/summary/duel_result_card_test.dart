import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/features/share/share_card_data.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social_controls.dart';
import 'package:slopetrack/features/social/social_models.dart';
import 'package:slopetrack/features/summary/tagesbilanz_screen.dart';
import 'package:slopetrack/platform/providers.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';
import '../social/duel/duel_fixtures.dart';
import '../today/today_fixtures.dart' show TestSettings, daySummary;
import 'summary_fixture.dart';

const _asked = Settings(notificationsAsked: true, onboardingDone: true);
final _twoDays = [daySummary(), daySummary(id: 'day-0')];

/// The Tagesbilanz fixture (day-1 on 2026-01-15 in Kitzbühel) plus the duel
/// and rank fakes.
List<Override> _overrides({FakeDuelApi? duel, FakeSocialApi? social}) => [
      dayDetailProvider.overrideWith((ref, id) => summaryDetail()),
      personalBestsProvider.overrideWith((ref) => Stream.value(const PersonalBests())),
      daysListProvider.overrideWith((ref) => Stream.value(_twoDays)),
      settingsProvider.overrideWith(() => TestSettings(_asked)),
      permissionServiceProvider.overrideWithValue(FakePermissionService()),
      ...duelOverrides(api: duel, social: social),
    ];

Future<void> _pumpSummary(WidgetTester tester, {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(tester, const TagesbilanzScreen(dayId: 'day-1'), overrides: overrides);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 240, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// The duel of the fixture day: Paul won, 'u1' second.
DuelSummary _todaysDuel() => duelSummary(id: 'g-today', code: 'KMJ4F2', name: 'Hahnenkamm-Crew', day: DateTime(2026, 1, 15), board: kFinalBoard.take(2).toList());

void main() {
  testWidgets('a duel for that day shows the result card with the winner ringed', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duels: [_todaysDuel(), duelSummary(id: 'g-old', day: DateTime(2026, 1, 10))]);
    await _pumpSummary(tester, overrides: _overrides(duel: api));
    await _scrollTo(tester, find.byType(DuelResultCard));

    expect(find.byType(DuelResultCard), findsOneWidget);
    expect(find.text('TAGESDUELL'), findsOneWidget);
    expect(find.text('Platz 2 von 2'), findsOneWidget);
    expect(find.text('Paul Moser'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
    expect(find.text('2.210'), findsOneWidget);
    expect(find.text('1.849'), findsOneWidget);

    final paul = tester.widget<AvatarCircle>(find.byWidgetPredicate((w) => w is AvatarCircle && w.name == 'Paul Moser'));
    final me = tester.widget<AvatarCircle>(find.byWidgetPredicate((w) => w is AvatarCircle && w.name == 'Sebastian Fackelmann'));
    expect(paul.ring, isTrue, reason: 'the winner is ringed');
    expect(paul.accent, isTrue);
    expect(me.ring, isFalse);
    final winnerValue = tester.widget<Text>(find.text('2.210'));
    expect(winnerValue.style?.color, AppColors.dark.accent);
    // Plain card: the one solid champagne moment stays with the record.
    expect(find.byWidgetPredicate((w) => w is AppCard && w.tone == CardTone.accent), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no duel that day, no card', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duels: [duelSummary(id: 'g-old', day: DateTime(2026, 1, 10))]);
    await _pumpSummary(tester, overrides: _overrides(duel: api));
    expect(find.byType(DuelResultCard), findsNothing);
  });

  testWidgets('without a backend neither the card nor the teaser show', (tester) async {
    await _pumpSummary(tester, overrides: _overrides());
    expect(find.byType(DuelResultCard), findsNothing);
    expect(find.byType(RankTeaser), findsOneWidget);
    expect(find.textContaining('Platz'), findsNothing);
    expect(find.text('1.804'), findsOneWidget);
  });

  testWidgets("the rank teaser renders 'Platz 14 in Kitzbühel · Saison' from my_rank", (tester) async {
    final social = FakeSocialApi(userId: 'u1', rank: const MyRank(rank: 14, total: 312, value: 12480));
    await _pumpSummary(tester, overrides: _overrides(social: social));

    expect(find.text('Platz 14 in Kitzbühel · Saison'), findsOneWidget);
    expect(social.rankQueries, isNotEmpty);
    expect(social.rankQueries.last.resortId, 'kitzbuehel');
    expect(social.rankQueries.last.seasonKey, '2025/26');
    expect(social.rankQueries.last.metric, SocialMetric.dropM);
  });

  testWidgets('not ranked: the teaser stays away', (tester) async {
    final social = FakeSocialApi(userId: 'u1', rank: null);
    await _pumpSummary(tester, overrides: _overrides(social: social));
    expect(find.textContaining('Platz'), findsNothing);
  });

  testWidgets('a duel still live says so instead of a place', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duels: [duelSummary(id: 'g-today', day: DateTime(2026, 1, 15), board: kLiveBoard)]);
    await _pumpSummary(tester, overrides: _overrides(duel: api));
    await _scrollTo(tester, find.byType(DuelResultCard));
    expect(find.text('Noch nicht alle im Ziel'), findsOneWidget);
  });

  testWidgets('Teilen on the card hands over to the share callback with the final board', (tester) async {
    var shared = 0;
    await pumpApp(
      tester,
      Scaffold(body: DuelResultCard(duel: _todaysDuel(), ownUserId: 'u1', onShare: () => shared++)),
      overrides: _overrides(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teilen'));
    await tester.pumpAndSettle();
    expect(shared, 1);
  });

  test('shareData builds the SHARE-CARDS duel payload with the own row marked', () {
    final card = DuelResultCard(duel: _todaysDuel(), ownUserId: 'u1', resortName: 'Kitzbühel');
    final data = card.shareData();
    expect(data.kind, ShareCardKind.duel);
    expect(data.name, 'Hahnenkamm-Crew');
    expect(data.resortName, 'Kitzbühel');
    expect(data.day, DateTime(2026, 1, 15).millisecondsSinceEpoch);
    expect(data.board.map((r) => r.displayName), ['Paul Moser', 'Sebastian Fackelmann']);
    expect(data.myPlace, 2);
    expect(data.board.last.isMe, isTrue);
  });
}
