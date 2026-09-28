import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/features/recording/live_state_provider.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/social_api.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../social_fixtures.dart';
import 'duel_fixtures.dart';

const _stats500 = DayStats(dropM: 500, runCount: 3, skiDistanceM: 4000, maxSpeedMs: 15);
const _stats900 = DayStats(dropM: 900, runCount: 5, skiDistanceM: 7000, maxSpeedMs: 17);

Segment _run(String id) => Segment(id: id, dayId: 'day-live', kind: SegmentKind.run, idx: 0, runNumber: 1, startTs: kTs, endTs: kTs + 300000, dropM: 200);

Future<ProviderContainer> _pump(WidgetTester tester, FakeDuelApi api) async {
  await pumpApp(
    tester,
    const LiveDuelSyncHost(child: Scaffold(body: Text('host'))),
    overrides: [
      ...screenOverrides(settings: const Settings(onboardingDone: true, lastResortId: 'kitzbuehel'), resorts: kResorts),
      ...duelOverrides(api: api),
    ],
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(LiveDuelSyncHost)));
}

void main() {
  testWidgets('with a live state and an active duel the api receives an upsert within the 120 s tick, none after endDay', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kLiveBoard);
    final c = await _pump(tester, api);
    await c.read(myDuelProvider.future);
    await tester.pump();
    expect(api.liveWrites, isEmpty, reason: 'nothing while not recording');

    // startDay: the engine already ticked once when the flag flips.
    c.read(liveStateNotifierProvider.notifier).set(const LiveState(stats: _stats500));
    c.read(isRecordingProvider.notifier).set(true);
    await tester.pump();
    expect(api.liveWrites, hasLength(1), reason: 'one write on activation');
    expect(api.liveWrites.first.dropM, 500);
    expect(api.liveWrites.first.day, DateTime(2026, 1, 15));
    expect(api.liveWrites.first.resortId, 'kitzbuehel');
    expect(api.liveWrites.first.toJson()['day'], '2026-01-15');

    // Numbers move, the tick writes them.
    c.read(liveStateNotifierProvider.notifier).set(const LiveState(stats: _stats900));
    await tester.pump(const Duration(seconds: 119));
    expect(api.liveWrites, hasLength(1), reason: 'not before the tick');
    await tester.pump(const Duration(seconds: 2));
    expect(api.liveWrites, hasLength(2));
    expect(api.liveWrites.last.dropM, 900);

    // Unchanged numbers: the next tick writes nothing.
    await tester.pump(const Duration(seconds: 120));
    expect(api.liveWrites, hasLength(2));

    // A finished run writes at once.
    c.read(liveStateNotifierProvider.notifier).set(LiveState(stats: const DayStats(dropM: 1100, runCount: 6), lastRun: _run('seg-6')));
    await tester.pump();
    expect(api.liveWrites, hasLength(3));
    expect(api.liveWrites.last.dropM, 1100);

    // endDay: nothing after it, whatever the live state does.
    c.read(isRecordingProvider.notifier).set(false);
    c.read(liveStateNotifierProvider.notifier).set(LiveState(stats: const DayStats(dropM: 1500, runCount: 8), lastRun: _run('seg-8')));
    await tester.pump(const Duration(seconds: 130));
    await tester.pump(const Duration(seconds: 130));
    expect(api.liveWrites, hasLength(3));
    expect(c.read(liveDuelUploaderProvider).isActive, isFalse);
  });

  testWidgets('without a duel nothing is written even while recording', (tester) async {
    final api = FakeDuelApi(userId: 'u1');
    final c = await _pump(tester, api);
    await c.read(myDuelProvider.future);
    c.read(isRecordingProvider.notifier).set(true);
    c.read(liveStateNotifierProvider.notifier).set(const LiveState(stats: _stats500));
    await tester.pump(const Duration(seconds: 125));
    expect(api.liveWrites, isEmpty);
    expect(c.read(liveDuelUploaderProvider).isActive, isFalse);
  });

  testWidgets('a duel joined mid-recording starts the uploader', (tester) async {
    final api = FakeDuelApi(userId: 'u1');
    final c = await _pump(tester, api);
    await c.read(myDuelProvider.future);
    c.read(isRecordingProvider.notifier).set(true);
    c.read(liveStateNotifierProvider.notifier).set(const LiveState(stats: _stats500));
    await tester.pump();
    expect(api.liveWrites, isEmpty);

    await api.joinDuel('KMJ4F2');
    c.invalidate(myDuelProvider);
    await c.read(myDuelProvider.future);
    await tester.pump();
    expect(api.liveWrites, hasLength(1));
    expect(c.read(liveDuelUploaderProvider).isActive, isTrue);

    c.read(isRecordingProvider.notifier).set(false);
    await tester.pump();
  });

  testWidgets('a failing write is swallowed and retried on the next tick', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup());
    final c = await _pump(tester, api);
    await c.read(myDuelProvider.future);
    api.failWith = const SocialError(SocialErrorKind.offline);
    c.read(liveStateNotifierProvider.notifier).set(const LiveState(stats: _stats500));
    c.read(isRecordingProvider.notifier).set(true);
    await tester.pump();
    expect(api.liveWrites, isEmpty);
    expect(tester.takeException(), isNull);

    api.failWith = null;
    await tester.pump(const Duration(seconds: 121));
    expect(api.liveWrites, hasLength(1));

    c.read(isRecordingProvider.notifier).set(false);
    await tester.pump();
  });
}
