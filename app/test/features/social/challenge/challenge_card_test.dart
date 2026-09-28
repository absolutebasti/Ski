import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../rider/rider_fixtures.dart';
import '../social_fixtures.dart';
import 'challenge_fixtures.dart';

/// Two days inside the window (1.800 + 2.200 = 4.000 hm), one before it.
final _days = [
  daySummary(id: 'in-1', startedAt: DateTime(2026, 1, 13, 10).millisecondsSinceEpoch, dropM: 1800),
  daySummary(id: 'in-2', startedAt: DateTime(2026, 1, 14, 10).millisecondsSinceEpoch, dropM: 2200),
  daySummary(id: 'out', startedAt: DateTime(2026, 1, 2, 10).millisecondsSinceEpoch, dropM: 9000),
];

FakeChallengeApi _api({String? userId = 'u1', Set<String>? joined, List<ChallengeHistoryEntry> history = const [], Map<String, List<ChallengeBoardEntry>>? boards}) =>
    FakeChallengeApi(userId: userId, challenges: [weekly()], joined: joined, boards: boards ?? {'c1': kChallengeBoard}, historyRows: history);

Future<void> _pump(
  WidgetTester tester, {
  required FakeChallengeApi? api,
  Challenge? challenge,
  bool signedIn = true,
  Locale locale = const Locale('de'),
  List<DaySummary>? days,
  bool showHistory = true,
}) async {
  await pumpApp(
    tester,
    Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(child: ChallengeCard(challenge: challenge ?? weekly(), now: kNow, showHistory: showHistory)),
    ),
    locale: locale,
    overrides: [
      ...screenOverrides(resorts: kResorts, days: days ?? _days),
      ...socialOverrides(api: FakeSocialApi(userId: signedIn ? 'u1' : null), user: signedIn ? kUser : null),
      ...challengeOverrides(api),
      ...riderOverrides(api: FakeRiderApi(profiles: {'u9': kLena})),
    ],
  );
  await tester.pumpAndSettle();
}

/// Records every haptic the platform channel receives.
List<String> _recordHaptics() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
    return null;
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

void main() {
  testWidgets('German: title column, local progress, target, days left, counts from the board', (tester) async {
    await _pump(tester, api: _api());

    expect(find.text('WOCHEN-CHALLENGE'), findsOneWidget);
    expect(find.text('Wochen-Challenge: 5.000 Höhenmeter'), findsOneWidget);
    expect(find.text('Weekly challenge: 5,000 m vertical'), findsNothing);
    expect(find.text('4.000'), findsOneWidget, reason: 'only the days inside the window count, computed locally');
    expect(find.text('5.000'), findsOneWidget);
    expect(find.text('Noch 3 Tage'), findsOneWidget);
    expect(find.text('3 dabei · 1 geschafft'), findsOneWidget);
    expect(find.text('Mitmachen'), findsOneWidget);
    expect(find.text('Dabei'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('English: the en title column and English counts', (tester) async {
    await _pump(tester, api: _api(), locale: const Locale('en'));

    expect(find.text('Weekly challenge: 5,000 m vertical'), findsOneWidget);
    expect(find.text('Wochen-Challenge: 5.000 Höhenmeter'), findsNothing);
    expect(find.text('3 in · 1 done'), findsOneWidget);
    expect(find.text('3 days left'), findsOneWidget);
    expect(find.text('Join in'), findsOneWidget);
  });

  testWidgets('without title columns the title is derived from metric + target', (tester) async {
    await _pump(tester, api: _api(), challenge: weekly(titleDe: null, titleEn: null, metric: SocialMetric.runCount, target: 20), locale: const Locale('en'));
    expect(find.text('Weekly challenge: 20 runs'), findsOneWidget);
  });

  testWidgets('Mitmachen inserts the participant row only, buzzes and flips to Dabei', (tester) async {
    final haptics = _recordHaptics();
    final api = _api();
    await _pump(tester, api: api);

    await tester.tap(find.text('Mitmachen'));
    await tester.pumpAndSettle();

    expect(api.joins, ['c1'], reason: 'the id only — there is no value to send');
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    expect(find.text('Du machst mit'), findsOneWidget);
    expect(find.text('Dabei'), findsOneWidget);
    expect(find.text('Mitmachen'), findsNothing);
    expect(find.byKey(const ValueKey('challenge-board')), findsOneWidget);
    expect(api.boardCalls.length, greaterThanOrEqualTo(2), reason: 'the board is refetched after the join');
  });

  testWidgets('already joined: Dabei chip and the Rangliste button', (tester) async {
    await _pump(tester, api: _api(joined: {'c1'}));

    expect(find.text('Dabei'), findsOneWidget);
    expect(find.text('Rangliste'), findsOneWidget);
    expect(find.text('Mitmachen'), findsNothing);
  });

  testWidgets('signed out: Mitmachen asks for a Konto and writes nothing', (tester) async {
    final haptics = _recordHaptics();
    final api = _api(userId: null);
    await _pump(tester, api: api, signedIn: false);

    await tester.tap(find.text('Mitmachen'));
    await tester.pumpAndSettle();

    expect(api.joins, isEmpty);
    expect(haptics, isEmpty);
    expect(find.text('Dafür brauchst du ein Konto'), findsOneWidget);
  });

  testWidgets('no backend: counts hidden, Mitmachen answers offline', (tester) async {
    await _pump(tester, api: null);

    expect(find.byKey(const ValueKey('challenge-counts')), findsNothing);
    expect(find.text('4.000'), findsOneWidget, reason: 'local progress needs no server');

    await tester.tap(find.text('Mitmachen'));
    await tester.pumpAndSettle();
    expect(find.text('Keine Verbindung'), findsOneWidget);
  });

  testWidgets('a closed window is reported as such', (tester) async {
    final api = _api();
    await _pump(tester, api: api);
    api.failWith = const SocialError(SocialErrorKind.failed, kChallengeEnded);

    await tester.tap(find.text('Mitmachen'));
    await tester.pumpAndSettle();

    expect(find.text('Die Challenge ist vorbei'), findsOneWidget);
    expect(find.text('Mitmachen'), findsOneWidget);
  });

  testWidgets('an empty board reads Noch niemand dabei', (tester) async {
    await _pump(tester, api: _api(boards: {}));
    expect(find.text('Noch niemand dabei'), findsOneWidget);
  });

  testWidgets('tapping the card opens the board sheet with tappable rows', (tester) async {
    await _pump(tester, api: _api(joined: {'c1'}));

    await tester.tap(find.text('Wochen-Challenge: 5.000 Höhenmeter'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('challenge-board-sheet')), findsOneWidget);
    expect(find.byType(ChallengeBoardRow), findsNWidgets(3));
    expect(find.text('Lena Bergmann'), findsOneWidget);
    expect(find.text('Tom Huber'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('challenge-row-u9')));
    await tester.pumpAndSettle();
    expect(find.byType(RiderSheetBody), findsOneWidget);
    expect(find.text('LEVEL 4 · CARVER'), findsOneWidget);
  });

  testWidgets('the Rangliste button opens the same sheet', (tester) async {
    await _pump(tester, api: _api(joined: {'c1'}));
    await tester.tap(find.byKey(const ValueKey('challenge-board')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('challenge-board-sheet')), findsOneWidget);
  });

  group('history', () {
    testWidgets('lists the ended challenges with rank, value and result', (tester) async {
      final api = _api(history: kChallengeHistory);
      await _pump(tester, api: api);

      expect(api.historyCalls, greaterThanOrEqualTo(1));
      expect(find.byKey(const ValueKey('challenge-history')), findsOneWidget);
      expect(find.text('Wochen-Challenge: 20 Abfahrten'), findsOneWidget);
      expect(find.text('Platz 2 von 12 · 23'), findsOneWidget);
      expect(find.text('Geschafft'), findsOneWidget);
      expect(find.text('Wochen-Challenge: 3 Skitage'), findsOneWidget);
      expect(find.text('Platz 5 von 8 · 1 Tage'), findsOneWidget);
      expect(find.text('Nicht geschafft'), findsOneWidget);
    });

    testWidgets('English history uses the en titles', (tester) async {
      await _pump(tester, api: _api(history: kChallengeHistory), locale: const Locale('en'));
      expect(find.text('Weekly challenge: 20 runs'), findsOneWidget);
      expect(find.text('Rank 2 of 12 · 23'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
    });

    testWidgets('a history row opens the ended board without a leave button', (tester) async {
      final api = _api(history: kChallengeHistory, boards: {'c1': kChallengeBoard, 'c0': kChallengeBoard});
      await _pump(tester, api: api);

      await tester.tap(find.byKey(const ValueKey('challenge-history-c0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('challenge-board-sheet')), findsOneWidget);
      expect(api.boardCalls, contains('c0'));
      expect(find.byKey(const ValueKey('challenge-leave')), findsNothing);
      final sheet = find.byKey(const ValueKey('challenge-board-sheet'));
      expect(find.descendant(of: sheet, matching: find.text('Noch 3 Tage')), findsNothing);
      expect(find.descendant(of: sheet, matching: find.textContaining('–')), findsOneWidget, reason: 'the window replaces the days-left caption');
    });

    testWidgets('nothing is drawn without history, signed out, or when disabled', (tester) async {
      await _pump(tester, api: _api());
      expect(find.byKey(const ValueKey('challenge-history')), findsNothing);

      await _pump(tester, api: _api(userId: null, history: kChallengeHistory), signedIn: false);
      expect(find.byKey(const ValueKey('challenge-history')), findsNothing);

      await _pump(tester, api: _api(history: kChallengeHistory), showHistory: false);
      expect(find.byKey(const ValueKey('challenge-history')), findsNothing);
    });
  });
}
