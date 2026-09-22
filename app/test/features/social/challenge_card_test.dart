import 'package:dropline/core/core.dart';
import 'package:dropline/core/settings.dart';
import 'package:dropline/features/social/fake_social_api.dart';
import 'package:dropline/features/social/social.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump.dart';
import '../../support/screen_overrides.dart';
import 'social_fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeSocialApi api, {List<DaySummary> days = const [], Challenge? challenge}) async {
  await pumpApp(
    tester,
    Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(child: ChallengeCard(challenge: challenge ?? weeklyChallenge(), now: kNow)),
    ),
    overrides: [
      ...screenOverrides(settings: const Settings(onboardingDone: true), resorts: kResorts, days: days),
      ...socialOverrides(api: api, user: kUser),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('target, local progress and the days left', (tester) async {
    await _pump(
      tester,
      FakeSocialApi(userId: 'u1'),
      days: [
        daySummary(id: 'in-1', startedAt: DateTime(2026, 1, 13, 10).millisecondsSinceEpoch, dropM: 1800),
        daySummary(id: 'in-2', startedAt: DateTime(2026, 1, 14, 10).millisecondsSinceEpoch, dropM: 2200),
        daySummary(id: 'out', startedAt: DateTime(2026, 1, 2, 10).millisecondsSinceEpoch, dropM: 9000),
      ],
    );

    expect(find.text('WOCHEN-CHALLENGE'), findsOneWidget);
    expect(find.text('10.000 hm in einer Woche'), findsOneWidget);
    expect(find.text('4.000'), findsOneWidget, reason: 'only the days inside the window count');
    expect(find.text('10.000'), findsOneWidget);
    expect(find.text('Noch 3 Tage'), findsOneWidget);
    expect(find.text('Mitmachen'), findsOneWidget);
  });

  testWidgets('Mitmachen writes the locally computed progress', (tester) async {
    final api = FakeSocialApi(userId: 'u1');
    await _pump(
      tester,
      api,
      days: [daySummary(id: 'in-1', startedAt: DateTime(2026, 1, 13, 10).millisecondsSinceEpoch, dropM: 1800)],
    );

    await tester.tap(find.text('Mitmachen'));
    await tester.pumpAndSettle();

    expect(api.progressWrites, [('c1', 1800.0)]);
    expect(find.text('Dabei'), findsOneWidget);
    expect(find.text('Mitmachen'), findsNothing);
  });

  testWidgets('already joined shows the Dabei chip and can update', (tester) async {
    final api = FakeSocialApi(userId: 'u1', progress: {'c1': 1000});
    await _pump(
      tester,
      api,
      days: [daySummary(id: 'in-1', startedAt: DateTime(2026, 1, 13, 10).millisecondsSinceEpoch, dropM: 2500)],
    );

    expect(find.text('Dabei'), findsOneWidget);
    await tester.tap(find.text('Stand melden'));
    await tester.pumpAndSettle();
    expect(api.progressWrites, [('c1', 2500.0)]);
  });

  testWidgets('signed out it asks for a Konto', (tester) async {
    final api = FakeSocialApi();
    await _pump(tester, api);

    await tester.tap(find.text('Mitmachen'));
    await tester.pumpAndSettle();

    expect(api.progressWrites, isEmpty);
    expect(find.text('Dafür brauchst du ein Konto'), findsOneWidget);
  });

  testWidgets('a run-count challenge counts runs, not metres', (tester) async {
    await _pump(
      tester,
      FakeSocialApi(userId: 'u1'),
      challenge: weeklyChallenge(target: 40, metric: SocialMetric.runCount),
      days: [
        daySummary(id: 'in-1', startedAt: DateTime(2026, 1, 13, 10).millisecondsSinceEpoch, runCount: 12),
        daySummary(id: 'in-2', startedAt: DateTime(2026, 1, 14, 10).millisecondsSinceEpoch, runCount: 9),
      ],
    );
    expect(find.text('21'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
  });
}
