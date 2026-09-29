import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/social_models.dart';
import 'package:slopetrack/features/today/duel_line.dart';
import 'package:slopetrack/features/today/heute_screen.dart';

import '../../support/pump.dart';
import '../social/duel/duel_fixtures.dart';
import '../social/social_fixtures.dart';
import 'today_fixtures.dart';

const _live = LiveState(
  stats: DayStats(elapsedMs: 3600 * 1000, skiMs: 1800 * 1000, runCount: 7, dropM: 1804, maxSpeedMs: 17),
  speedMs: 12.5,
  altM: 1830,
  state: MotionState.run,
  gps: GpsQuality.good,
);

/// Three members: Lena leads by 120 hm over the own live 1.804, Anna trails.
const _board = [
  DuelMember(userId: 'u2', displayName: 'Lena', runCount: 8, dropM: 1924, maxSpeedMs: 18),
  DuelMember(userId: 'u1', displayName: 'Sebastian Fackelmann', runCount: 6, dropM: 1500, maxSpeedMs: 17, isLive: true),
  DuelMember(userId: 'u3', displayName: 'Anna', runCount: 5, dropM: 1500, maxSpeedMs: 15),
];

Future<void> _pumpLive(WidgetTester tester, FakeDuelApi? api) async {
  final ctrl = FakeRecordingController(
    initial: RecordingState(status: RecordingStatus.recording, dayId: 'day-live', startedAt: tsDay),
  );
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    const HeuteScreen(),
    overrides: [
      ...todayOverrides(controller: ctrl, live: _live, activeResortName: 'Kitzbühel'),
      ...duelOverrides(api: api, user: kUser, poll: null),
    ],
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('DuelStanding', () {
    test('behind: place counts the riders ahead, gap to the leader', () {
      final st = DuelStanding.of(_board, ownUserId: 'u1', ownDropM: 1804);
      expect(st.place, 2);
      expect(st.other?.displayName, 'Lena');
      expect(st.gapM, 120);
      expect(st.leading, isFalse);
    });

    test('leading: gap to the runner-up; the own board row is ignored', () {
      final st = DuelStanding.of(_board, ownUserId: 'u1', ownDropM: 2000);
      expect(st.place, 1);
      expect(st.other?.displayName, 'Lena');
      expect(st.gapM, 76);
      expect(st.leading, isTrue);
    });

    test('alone on the board', () {
      const only = [GroupMemberStats(userId: 'u1', displayName: 'Ich', dropM: 900)];
      final st = DuelStanding.of(only, ownUserId: 'u1', ownDropM: 900);
      expect(st.place, 1);
      expect(st.other, isNull);
    });
  });

  testWidgets('live with a duel board shows own place and the gap to the leader', (tester) async {
    await _pumpLive(tester, FakeDuelApi(userId: 'u1', duel: duelGroup(), board: _board));
    expect(find.text('Duell: Platz 2 · Lena +120 hm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leading reads the gap to the runner-up', (tester) async {
    final board = [
      const DuelMember(userId: 'u2', displayName: 'Paul Moser', dropM: 1700),
      const DuelMember(userId: 'u1', displayName: 'Sebastian Fackelmann', dropM: 1600, isLive: true),
    ];
    await _pumpLive(tester, FakeDuelApi(userId: 'u1', duel: duelGroup(), board: board));
    expect(find.text('Duell: Platz 1 · 104 hm vor Paul Moser'), findsOneWidget);
  });

  testWidgets('without a duel the line is absent', (tester) async {
    await _pumpLive(tester, FakeDuelApi(userId: 'u1'));
    expect(find.byKey(const ValueKey('live-duel-line')), findsNothing);
    expect(find.textContaining('Duell:'), findsNothing);
  });

  testWidgets('offline (no api) the line is absent and nothing throws', (tester) async {
    await _pumpLive(tester, null);
    expect(find.textContaining('Duell:'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
