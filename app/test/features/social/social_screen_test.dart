import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/features/days/resort_picker.dart';
import 'package:slopetrack/features/share/share_card_data.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';
import 'package:slopetrack/features/social/teaser/teaser.dart';

import '../../support/pump.dart';
import '../../support/screen_overrides.dart';
import 'social_fixtures.dart';

const _settings = Settings(onboardingDone: true, lastResortId: 'kitzbuehel', countryCode: 'AT');
const _noHome = Settings(onboardingDone: true, countryCode: 'AT');

const _lena = Friend(userId: 'u9', displayName: 'Lena Bergmann', countryCode: 'AT');
const _ninaRequest = Friend(userId: 'u7', displayName: 'Nina Aigner', status: FriendshipStatus.pending, incoming: true);
const _paulRequest = Friend(userId: 'u8', displayName: 'Paul Moser', status: FriendshipStatus.pending, incoming: true);

/// The bundled list has 4.929 areas — the Gebiet scope must not render one
/// chip per resort. The two fixture resorts come first so ids stay stable.
List<Resort> _manyResorts([int n = 4929]) => [
      ...kResorts,
      for (var i = kResorts.length; i < n; i++)
        Resort(id: 'area-at-${i.toString().padLeft(6, '0')}', name: 'Area $i', country: 'AT', lat: 47 + (i % 100) / 100, lon: 10 + (i % 300) / 100, radiusKm: 5),
    ];


/// The metric and scope chips scroll horizontally (lazy ListView): drag the
/// row that contains [anchor] until [label] is built and on screen.
Future<void> _revealChip(WidgetTester tester, String label, {String anchor = 'Höhenmeter'}) async {
  final chips = find.ancestor(of: find.text(anchor), matching: find.byType(ListView)).first;
  await tester.dragUntilVisible(find.text(label), chips, const Offset(-160, 0));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  FakeSocialApi? api,
  FakeTeaserApi? teaser,
  bool signedIn = true,
  VoidCallback? onOpenAccount,
  List<DaySummary> days = const [],
  Settings settings = _settings,
  List<Resort> resorts = kResorts,
  List<Override> extra = const [],
  Locale locale = const Locale('de'),
}) async {
  // Tall phone surface: the achievements header sits above the board, so the
  // tabs and chips must stay on screen without scrolling.
  tester.view.physicalSize = const Size(1179, 5400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    SocialScreen(now: kNow, onOpenAccount: onOpenAccount),
    locale: locale,
    overrides: [
      ...screenOverrides(settings: settings, resorts: resorts, days: days),
      ...socialOverrides(api: api, user: signedIn ? kUser : null),
      // The public top 10 of the signed-out tab; never the Supabase client.
      teaserApiProvider.overrideWithValue(teaser),
      ...extra,
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('signed out (teaser)', () {
    testWidgets('the public top 10, locked duel and challenge previews, sign-in pinned', (tester) async {
      var opened = 0;
      final api = FakeSocialApi();
      final teaser = FakeTeaserApi.topTen();
      await _pump(tester, api: api, teaser: teaser, signedIn: false, onOpenAccount: () => opened++);

      expect(find.text('Rangliste'), findsOneWidget);
      expect(find.text('Saison 2025/26 · Kitzbühel'), findsOneWidget);
      expect(teaser.calls, [const TeaserQuery(seasonKey: '2025/26', resortId: 'kitzbuehel')]);

      // Ten plain rows by points — no podium (a podium column opens a rider).
      expect(find.byType(TeaserRows), findsOneWidget);
      expect(find.byType(LeaderboardRow), findsNWidgets(10));
      expect(find.byType(LeaderboardPodium), findsNothing);
      expect(find.text('Lena Bergmann'), findsOneWidget);
      expect(find.text('Max Steiner'), findsOneWidget);
      expect(find.text('4.200'), findsOneWidget);
      expect(find.text('Pkt.'), findsWidgets);
      expect(find.byKey(const ValueKey('board-skeleton')), findsNothing);

      // Duel and challenge: previews with a lock, none of the real cards.
      expect(find.byType(TeaserLockedCard), findsNWidgets(2));
      expect(find.text('TAGESDUELL'), findsOneWidget);
      expect(find.text('Duell mit bis zu 3 Freunden · Code teilen'), findsOneWidget);
      expect(find.text('WOCHEN-CHALLENGE'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
      expect(find.byType(DuelCard), findsNothing);
      expect(find.byType(ChallengeCard), findsNothing);
      expect(find.byType(CountryBoardCard), findsNothing);

      // Create / join / opt-in stay behind the Konto.
      expect(find.text('Duell starten'), findsNothing);
      expect(find.text('Code eingeben'), findsNothing);
      expect(find.text('Mitmachen'), findsNothing);
      expect(find.text('Rangliste freischalten'), findsNothing);
      expect(find.byKey(const ValueKey('friends-button')), findsNothing, reason: 'friends need a Konto');
      expect(find.byType(OwnRankStrip), findsNothing);

      // The sign-in sits where the own-rank strip sits; 'Platz 1' is said once.
      expect(find.byType(TeaserSignInStrip), findsOneWidget);
      expect(find.text('Hol dir Platz 1.'), findsOneWidget);
      expect(find.text('Melde dich an und fahr gegen Kitzbühel.'), findsOneWidget);
      expect(find.textContaining('Platz 1'), findsOneWidget);
      final strip = tester.getRect(find.byType(TeaserSignInStrip));
      expect(strip.bottom, tester.getRect(find.byType(SocialScreen)).bottom, reason: 'pinned to the bottom edge, above the tab bar inset');

      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      expect(opened, 1);

      // Nothing that needs a session was asked for.
      expect(api.queries, isEmpty);
      expect(api.rankQueries, isEmpty);
      expect(api.countryBoardCalls, isEmpty);
      expect(api.boardCalls, isEmpty);
      expect(api.created, isEmpty);
      expect(api.joined, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('period tabs and chips are visible but switched off', (tester) async {
      final api = FakeSocialApi();
      final teaser = FakeTeaserApi.topTen();
      await _pump(tester, api: api, teaser: teaser, signedIn: false);

      final filters = find.byKey(const ValueKey('teaser-filters'));
      expect(filters, findsOneWidget);
      expect(find.descendant(of: filters, matching: find.byType(SocialSegmentTabs)), findsOneWidget);
      expect(find.descendant(of: filters, matching: find.byType(SocialChipRow)), findsNWidgets(2));
      expect(tester.widget<SocialSegmentTabs>(find.byType(SocialSegmentTabs)).index, 0, reason: 'Saison');
      // What the teaser ranks is what is selected: the Gebiet, by points.
      SocialFilterChip chip(String label) => tester.widget<SocialFilterChip>(find.widgetWithText(SocialFilterChip, label));
      expect(chip('Gebiet').selected, isTrue);
      expect(chip('Punkte').selected, isTrue);
      expect(chip('Alle').selected, isFalse);
      expect(chip('Höhenmeter').selected, isFalse);
      expect(find.text('Gebiet: Kitzbühel'), findsOneWidget);
      // No pointer reaches a tab or a chip.
      final ignore = tester.widget<IgnorePointer>(find.descendant(of: filters, matching: find.byType(IgnorePointer)).first);
      expect(ignore.ignoring, isTrue);

      for (final label in ['Monat', 'Woche', 'Alle', 'Höhenmeter', 'Gebiet: Kitzbühel']) {
        await tester.tap(find.text(label), warnIfMissed: false);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.widget<SocialSegmentTabs>(find.byType(SocialSegmentTabs)).index, 0);
      expect(chip('Gebiet').selected, isTrue);
      expect(chip('Punkte').selected, isTrue);
      expect(find.text('Saison 2025/26 · Kitzbühel'), findsOneWidget, reason: 'the caption did not move to month / week / all');
      expect(find.byType(ResortPickerSheet), findsNothing);
      expect(teaser.calls, hasLength(1), reason: 'no re-query');
      expect(api.queries, isEmpty);
      // The block says why instead of doing nothing.
      expect(find.text('Dafür brauchst du ein Konto'), findsWidgets);

      // Let the toasts run out.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('tapping a teaser row shows the sign-in toast and opens no rider', (tester) async {
      await _pump(tester, api: FakeSocialApi(), teaser: FakeTeaserApi.topTen(), signedIn: false);

      await tester.tap(find.text('Lena Bergmann'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Anmelden, um Profile zu sehen'), findsOneWidget);
      expect(find.byType(RiderSheetBody), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Anmelden, um Profile zu sehen'), findsNothing);
    });

    testWidgets('a locked preview card leads to the sign-in', (tester) async {
      var opened = 0;
      await _pump(tester, api: FakeSocialApi(), teaser: FakeTeaserApi.topTen(), signedIn: false, onOpenAccount: () => opened++);

      await tester.tap(find.byKey(const ValueKey('teaser-duel')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      await tester.tap(find.byKey(const ValueKey('teaser-challenge')));
      await tester.pumpAndSettle();
      expect(opened, 2);
    });

    testWidgets('empty teaser: ghost rows and the sign-in, Platz 1 is not repeated', (tester) async {
      var opened = 0;
      final teaser = FakeTeaserApi();
      await _pump(tester, api: FakeSocialApi(), teaser: teaser, signedIn: false, onOpenAccount: () => opened++);

      expect(teaser.calls, hasLength(1));
      expect(find.byKey(const ValueKey('board-skeleton')), findsOneWidget);
      expect(find.byType(LeaderboardRow), findsNothing);
      expect(find.byType(TeaserRows), findsNothing);
      expect(find.text('In Kitzbühel ist noch niemand gewertet.'), findsOneWidget);
      // The old card said 'Platz 1' in headline and line; now once, in the strip.
      expect(find.textContaining('Platz 1'), findsOneWidget);
      expect(find.byType(SocialStateBlock), findsNothing);
      expect(find.byType(TeaserLockedCard), findsNWidgets(2));
      expect(find.byType(TeaserSignInStrip), findsOneWidget);

      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('teaser offline: ghost rows with the offline line, sign-in stays', (tester) async {
      await _pump(
        tester,
        api: FakeSocialApi(),
        teaser: FakeTeaserApi(entries: FakeTeaserApi.sample(), failWith: const SocialError(SocialErrorKind.offline)),
        signedIn: false,
      );
      expect(find.byKey(const ValueKey('board-skeleton')), findsOneWidget);
      expect(find.byType(LeaderboardRow), findsNothing);
      expect(find.text('Keine Verbindung. Die Vorschau lädt, sobald du Netz hast.'), findsOneWidget);
      expect(find.byType(TeaserSignInStrip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a home resort the teaser ranks every resort', (tester) async {
      final teaser = FakeTeaserApi.topTen();
      await _pump(tester, api: FakeSocialApi(), teaser: teaser, signedIn: false, settings: _noHome);

      expect(teaser.calls, [const TeaserQuery(seasonKey: '2025/26')]);
      expect(find.text('Saison 2025/26 · Alle Gebiete'), findsOneWidget);
      expect(find.text('Melde dich an und fahr gegen alle anderen.'), findsOneWidget);
      expect(find.text('Gebiet'), findsNothing);
      expect(find.textContaining('Gebiet:'), findsNothing);
      expect(tester.widget<SocialFilterChip>(find.widgetWithText(SocialFilterChip, 'Alle')).selected, isTrue);
      expect(find.byType(LeaderboardRow), findsNWidgets(10));
    });

    testWidgets('more than ten rows from the server are cut to ten', (tester) async {
      final rows = [for (var i = 1; i <= 14; i++) TeaserEntry(rank: i, displayName: 'Rider $i', value: 5000.0 - i * 100)];
      await _pump(tester, api: FakeSocialApi(), teaser: FakeTeaserApi(entriesFor: (_) => rows), signedIn: false);
      // The fake caps like the server; the widget caps again on its own.
      expect(find.byType(LeaderboardRow), findsNWidgets(10));
      expect(find.text('Rider 11'), findsNothing);
    });

    testWidgets('English: previews, toast copy and the strip', (tester) async {
      await _pump(tester, api: FakeSocialApi(), teaser: FakeTeaserApi.topTen(), signedIn: false, locale: const Locale('en'));
      expect(find.text('Duel with up to 3 friends · share a code'), findsOneWidget);
      expect(find.text('Go for first place.'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      await tester.tap(find.text('Lena Bergmann'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sign in to see profiles'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('without a backend the tab is offline, not broken', (tester) async {
    await _pump(tester, api: null);
    expect(find.text('Keine Verbindung.'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed in but not opted in: explainer instead of the board', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', optedIn: false, entries: kEntries),
      onOpenAccount: () => opened++,
    );

    expect(find.text('Deine Zahlen sind noch privat.'), findsOneWidget);
    expect(find.byType(LeaderboardPodium), findsNothing);
    expect(find.text('TAGESDUELL'), findsOneWidget, reason: 'the duel does not need the opt-in');

    await tester.ensureVisible(find.text('Rangliste freischalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rangliste freischalten'));
    await tester.pumpAndSettle();
    // The opt-in is inline now (profile update); the Konto sheet stays closed.
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('podium, rows and the own row pinned at the bottom', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1', entries: kEntries));

    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.text('Lena Bergmann'), findsOneWidget);
    expect(find.text('24.100'), findsOneWidget);
    expect(find.text('Paul Moser'), findsOneWidget);
    // Rank 4 and 5 are rows, not podium columns.
    expect(find.byType(LeaderboardRow), findsNWidgets(2));
    expect(find.text('Tom Huber'), findsOneWidget);
    // 12.480 shows in the own row and once more in the pinned strip.
    expect(find.byType(OwnRankStrip), findsOneWidget);
    expect(find.text('Du · Platz 4 von 5'), findsOneWidget, reason: 'no server total → the slice size');
    expect(find.text('12.480'), findsNWidgets(2));
  });

  testWidgets('the own row strip shows the server participant count', (tester) async {
    final entries = [for (final e in kEntries) LeaderboardEntry(rank: e.rank, userId: e.userId, displayName: e.displayName, value: e.value, total: 250)];
    await _pump(tester, api: FakeSocialApi(userId: 'u1', entries: entries));
    expect(find.text('Du · Platz 4 von 250'), findsOneWidget);
  });

  testWidgets('outside the slice and not ranked: the strip says so, without a share glyph', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1', entries: kEntries.take(3).toList()));
    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.byType(OwnRankStrip), findsOneWidget);
    expect(find.text('Du bist noch nicht gewertet'), findsOneWidget);
    expect(find.byKey(const ValueKey('own-rank-share')), findsNothing);
  });

  testWidgets('outside the slice but ranked server-side: my_rank fills the strip', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1', entries: kEntries.take(3).toList(), rank: const MyRank(rank: 140, total: 900, value: 3200)));
    expect(find.text('Du · Platz 140 von 900'), findsOneWidget);
    expect(find.text('Zu mir springen'), findsOneWidget);
  });

  testWidgets('while my_rank loads nothing is pinned', (tester) async {
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', entries: kEntries.take(3).toList()),
      extra: [myRankProvider.overrideWith((ref, query) => Completer<MyRank?>().future)],
    );
    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.byType(OwnRankStrip), findsNothing);
    expect(find.text('Du bist noch nicht gewertet'), findsNothing);
  });

  testWidgets('not opted in: no strip even when my_rank is null', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1', optedIn: false, entries: kEntries.take(3).toList()));
    expect(find.byType(OwnRankStrip), findsNothing);
  });

  testWidgets('empty board invites friends', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1'));
    expect(find.text('Sei der Erste in Kitzbühel.'), findsOneWidget);
    expect(find.text('Freunde einladen'), findsOneWidget);
    expect(find.text('Du bist noch nicht gewertet'), findsOneWidget, reason: 'opted in, board loaded, no row');
  });

  testWidgets('the share glyph on the own row hands a rank card to the share service', (tester) async {
    final shared = <RankCardData>[];
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', entries: kEntries),
      extra: [rankShareProvider.overrideWithValue((context, data) async => shared.add(data))],
    );
    expect(find.byKey(const ValueKey('own-rank-share')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('own-rank-share')));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    final card = shared.single;
    expect(card.kind, ShareCardKind.rank);
    expect(card.rank, 4);
    expect(card.total, 5);
    expect(card.value, 12480);
    expect(card.metric, ShareMetric.vertical);
    expect(card.seasonKey, '2025/26');
    expect(card.scopeName, 'Kitzbühel');
    expect(card.periodLabel, isNull, reason: 'the card renders the season itself');
  });

  testWidgets('the share card of a week board carries the week label', (tester) async {
    final shared = <RankCardData>[];
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', entries: kEntries),
      extra: [rankShareProvider.overrideWithValue((context, data) async => shared.add(data))],
    );
    await tester.ensureVisible(find.text('Woche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('own-rank-share')));
    await tester.pumpAndSettle();
    expect(shared.single.periodLabel, 'KW 03');
  });

  testWidgets('a failing call falls back to the offline state', (tester) async {
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', entries: kEntries, failWith: const SocialError(SocialErrorKind.offline)),
    );
    expect(find.text('Keine Verbindung.'), findsOneWidget);
    expect(find.text('Deine Zahlen sind noch privat.'), findsNothing);
  });

  testWidgets('the metric chips re-query and re-unit the board', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    expect(api.queries.last.metric, SocialMetric.dropM);

    await _revealChip(tester, 'Top-Speed');
    await tester.tap(find.text('Top-Speed'));
    await tester.pumpAndSettle();

    expect(api.queries.last.metric, SocialMetric.maxSpeedMs);
    expect(find.text('km/h'), findsWidgets);
  });

  testWidgets('the period tabs send the month and week key', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    expect(api.queries.last.wireKey, '2025/26');
    await tester.ensureVisible(find.text('Woche'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    expect(api.queries.last.wireKey, '2026-W03');
    expect(find.text('Diese Woche · Kitzbühel'), findsOneWidget);

    await tester.ensureVisible(find.text('Monat'));
    await tester.tap(find.text('Monat'));
    await tester.pumpAndSettle();
    expect(api.queries.last.wireKey, '2026-01');
  });

  testWidgets('the scope row defaults to the home resort and switches the query', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    expect(api.queries.last.resortId, 'kitzbuehel');
    expect(api.queries.last.countryCode, isNull);
    expect(find.text('Saison 2025/26 · Kitzbühel'), findsOneWidget);
    expect(find.text('Gebiet'), findsOneWidget);
    expect(find.text('Gebiet: Kitzbühel'), findsOneWidget, reason: 'one picker chip under Gebiet');
    expect(find.text('Ischgl'), findsNothing, reason: 'no chip per resort');

    await _revealChip(tester, 'Alle', anchor: 'Gebiet');
    await tester.tap(find.text('Alle'));
    await tester.pumpAndSettle();
    expect(api.queries.last.resortId, isNull);
    expect(api.queries.last.countryCode, isNull);
    expect(find.text('Saison 2025/26 · Alle Gebiete'), findsOneWidget);
    expect(find.byKey(const ValueKey('resort-chip')), findsNothing, reason: 'the picker chip hides outside Gebiet');

    await tester.tap(find.text('Mein Land 🇦🇹'));
    await tester.pumpAndSettle();
    expect(api.queries.last.countryCode, 'AT');
    expect(api.queries.last.resortId, isNull);
    expect(api.queries.last.scope, LeaderboardScope.country);
    expect(find.text('Saison 2025/26 · Österreich'), findsOneWidget);

    await tester.tap(find.text('Gebiet'));
    await tester.pumpAndSettle();
    // The Kitzbühel query is cached by the family — no second fetch, but the
    // caption and the picker chip are back.
    expect(find.text('Saison 2025/26 · Kitzbühel'), findsOneWidget);
    expect(find.text('Gebiet: Kitzbühel'), findsOneWidget);
  });

  testWidgets('with 4.929 resorts the Gebiet scope renders one chip that opens the picker', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api, resorts: _manyResorts());
    expect(find.byKey(const ValueKey('resort-chip')), findsOneWidget);
    expect(find.byType(SocialPickerChip), findsOneWidget);
    expect(find.textContaining('Area '), findsNothing, reason: 'no chip per resort');
    expect(find.byType(ResortPickerSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('resort-chip')));
    await tester.pumpAndSettle();
    expect(find.byType(ResortPickerSheet), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('resort-picker-search')), 'Ischgl');
    await tester.pumpAndSettle();
    // The search field echoes the query — tap the row, not the input.
    await tester.tap(find.descendant(of: find.byType(ListView), matching: find.text('Ischgl')));
    await tester.pumpAndSettle();

    expect(find.byType(ResortPickerSheet), findsNothing);
    expect(api.queries.last.resortId, 'ischgl');
    expect(api.queries.last.scope, LeaderboardScope.resort);
    expect(find.text('Gebiet: Ischgl'), findsOneWidget);
    expect(find.text('Saison 2025/26 · Ischgl'), findsOneWidget);
  });

  testWidgets('dismissing the picker keeps the current Gebiet', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    final before = api.queries.length;
    await tester.tap(find.byKey(const ValueKey('resort-chip')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(ResortPickerSheet), findsNothing);
    expect(api.queries.length, before);
    expect(api.queries.last.resortId, 'kitzbuehel');
  });

  testWidgets('without a home resort and without days the Gebiet scope is absent', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api, settings: _noHome);
    expect(find.text('Gebiet'), findsNothing);
    expect(find.byKey(const ValueKey('resort-chip')), findsNothing);
    // The default falls through to the team country — never `resorts.all.first`.
    expect(api.queries.last.resortId, isNull);
    expect(api.queries.last.countryCode, 'AT');
    expect(find.text('Saison 2025/26 · Österreich'), findsOneWidget);
  });

  testWidgets('without a home resort the last local day picks the Gebiet', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(
      tester,
      api: api,
      settings: _noHome,
      days: [
        DaySummary(id: 'newest', startedAt: kTs - 86400000, resortId: 'ischgl', resortName: 'Ischgl', stats: const DayStats(runCount: 5, dropM: 3000)),
        DaySummary(id: 'older', startedAt: kTs - 3 * 86400000, resortId: 'kitzbuehel', resortName: 'Kitzbühel', stats: const DayStats(runCount: 5, dropM: 3000)),
      ],
    );
    expect(find.text('Gebiet'), findsOneWidget);
    expect(find.text('Gebiet: Ischgl'), findsOneWidget);
    expect(api.queries.last.resortId, 'ischgl');
    expect(find.text('Saison 2025/26 · Ischgl'), findsOneWidget);
  });

  testWidgets('the Freunde header button carries the pending badge and opens the sheet', (tester) async {
    final friends = FakeFriendsApi(userId: 'u1', friends: const [_lena, _ninaRequest, _paulRequest]);
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', entries: kEntries),
      extra: [friendsApiProvider.overrideWithValue(friends)],
    );
    expect(find.byKey(const ValueKey('friends-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('friends-badge')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('friends-badge')), matching: find.text('2')), findsOneWidget);
    expect(find.byType(FriendsSheetBody), findsNothing);

    await tester.tap(find.byKey(const ValueKey('friends-button')));
    await tester.pumpAndSettle();
    expect(find.byType(FriendsSheetBody), findsOneWidget);
    expect(find.text('Lena Bergmann'), findsWidgets);
  });

  testWidgets('one friend and no requests: button without badge', (tester) async {
    final friends = FakeFriendsApi(userId: 'u1', friends: const [_lena]);
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', entries: kEntries),
      extra: [friendsApiProvider.overrideWithValue(friends)],
    );
    expect(find.byKey(const ValueKey('friends-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('friends-badge')), findsNothing);
  });

  testWidgets('without a team country the Mein Land chip is hidden', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api, settings: const Settings(onboardingDone: true, lastResortId: 'kitzbuehel'));
    expect(find.textContaining('Mein Land'), findsNothing);
    expect(find.text('Gebiet'), findsOneWidget);
    expect(find.text('Alle'), findsOneWidget);
  });

  testWidgets('the Punkte chip wires the points metric', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);

    await _revealChip(tester, 'Punkte');
    await tester.tap(find.text('Punkte'));
    await tester.pumpAndSettle();

    expect(api.queries.last.metric, SocialMetric.points);
    expect(api.queries.last.metric.wire, 'points');
    expect(find.text('Pkt.'), findsWidgets);
  });

  testWidgets('the Länder card asks country_board for the period key and rings the own team', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries, countries: kCountries);
    await _pump(tester, api: api);
    expect(api.countryBoardCalls.last, '2025/26');

    await tester.ensureVisible(find.byType(CountryBoardCard));
    await tester.pumpAndSettle();
    expect(find.text('LÄNDER'), findsOneWidget);
    expect(find.text('Team-Wertung · Saison'), findsOneWidget);
    expect(find.text('Schweiz'), findsOneWidget);
    expect(find.text('Österreich'), findsOneWidget);
    expect(find.text('250 Fahrer'), findsOneWidget);
    expect(find.text('91.234'), findsOneWidget);
    final flags = tester.widgetList<CountryFlag>(find.byType(CountryFlag)).toList();
    expect(flags.where((f) => f.ring).map((f) => f.countryCode), ['AT']);

    await tester.ensureVisible(find.text('Woche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    expect(api.countryBoardCalls.last, '2026-W03');
  });

  testWidgets('duel and challenge sit above the board', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries, duel: duelGroup(), board: kBoard, challenges: [weeklyChallenge()]);
    await _pump(
      tester,
      api: api,
      days: [daySummary(id: 'in-1', startedAt: DateTime(2026, 1, 13, 10).millisecondsSinceEpoch, dropM: 4000)],
    );

    expect(find.byType(DuelCard), findsOneWidget);
    expect(find.text('KMJ4F2'), findsOneWidget);
    expect(find.byType(ChallengeCard), findsOneWidget);
    expect(find.text('10.000 hm in einer Woche'), findsOneWidget);
    expect(find.text('4.000'), findsOneWidget);
    expect(find.byType(LeaderboardPodium), findsOneWidget);
  });
}
