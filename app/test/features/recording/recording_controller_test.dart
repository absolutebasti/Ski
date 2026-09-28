import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/features/recording/recording.dart';
import 'package:slopetrack/platform/permission_service.dart';
import 'package:slopetrack/tracking/synthetic.dart';

import 'harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('start → feed a synthetic day → end stores the right numbers', () async {
    final day = SyntheticDayGenerator(seed: 7).generate();
    final h = Harness(db, startMs: day.pressures.first.ts - 1000);
    await h.ctrl.startDay();
    expect(h.container.read(recordingControllerProvider).isRecording, isTrue);
    expect(h.container.read(isRecordingProvider), isTrue);
    expect(h.loc.isRunning, isTrue);
    expect(h.watchdog.running, isTrue);

    await h.feed(day);
    final live = h.container.read(liveStateProvider);
    expect(live.stats.runCount, day.expectedRuns);
    expect(h.container.read(liveTrackProvider).length, TrackingConfig.liveRingPoints);

    final id = await h.ctrl.endDay();
    expect(id, isNotNull);
    expect(h.container.read(recordingControllerProvider).status, RecordingStatus.idle);
    expect(h.container.read(isRecordingProvider), isFalse);
    expect(h.loc.isRunning, isFalse);

    final repo = h.container.read(daysRepositoryProvider);
    final d = await repo.day(id!);
    expect(d!.status, DayStatus.finished);
    expect(d.stats.runCount, day.expectedRuns);
    expect(d.stats.liftCount, day.expectedLifts);
    expect(d.stats.dropM, closeTo(day.expectedDropM, day.expectedDropM * 0.03));
    expect(d.resortId, 'kitzbuehel');
    expect((await repo.pointsRaw(id)).length, day.pressures.length);
    expect((await repo.segmentsOf(id)).length, greaterThan(4));
  });

  test('too short a day is discarded', () async {
    final day = SyntheticDayGenerator(seed: 2).generate(const [Phase.stop(40)]);
    final h = Harness(db, startMs: day.pressures.first.ts - 1000);
    await h.ctrl.startDay();
    await h.feed(day);
    final id = await h.ctrl.endDay();
    expect(id, isNull);
    expect(await h.container.read(daysRepositoryProvider).activeDay(), isNull);
    expect((await h.container.read(daysRepositoryProvider).watchDays().first), isEmpty);
  });

  test('kill mid-day → resumeIfActive continues with the same totals', () async {
    final day = SyntheticDayGenerator(seed: 7).generate();
    final h1 = Harness(db, startMs: day.pressures.first.ts - 1000);
    await h1.ctrl.startDay();
    final half = day.pressures.length ~/ 2;
    await h1.feed(day, to: half);
    final activeId = h1.container.read(recordingControllerProvider).dayId!;
    // simulate a kill: drop the container without endDay (points flushed by the writer)
    h1.container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final h2 = Harness(db, startMs: day.pressures[half].ts);
    expect(await h2.ctrl.resumeIfActive(), isTrue);
    expect(h2.container.read(recordingControllerProvider).dayId, activeId);
    await h2.feed(day, from: half);
    final id = await h2.ctrl.endDay();
    expect(id, activeId);
    final d = await h2.container.read(daysRepositoryProvider).day(id!);
    expect(d!.stats.runCount, day.expectedRuns);
    expect(d.stats.dropM, closeTo(day.expectedDropM, day.expectedDropM * 0.03));
  });

  test('old active day is offered for recovery, not resumed', () async {
    final day = SyntheticDayGenerator(seed: 3).generate();
    final h1 = Harness(db, startMs: day.pressures.first.ts - 1000);
    await h1.ctrl.startDay();
    await h1.feed(day, to: 900);
    h1.container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final h2 = Harness(db, startMs: day.pressures[900].ts + 2 * 3600000);
    expect(await h2.ctrl.resumeIfActive(), isFalse);
    final info = await h2.container.read(recoveryProvider.future);
    expect(info, isNotNull);
    final id = await h2.ctrl.endRecoveredDay(info!.dayId);
    expect(id, info.dayId);
    expect((await h2.container.read(daysRepositoryProvider).day(id!))!.status, DayStatus.finished);
    expect(await h2.container.read(recoveryProvider.future), isNull);
  });

  test('denied location blocks start', () async {
    final h = Harness(db);
    h.perm.state = LocationPermissionState.denied;
    await expectLater(h.ctrl.startDay(), throwsA(isA<RecordingError>()));
    expect(h.container.read(recordingControllerProvider).status, RecordingStatus.idle);
  });

  test('first fix outside any resort leaves the day unresolved; a later fix inside sets it', () async {
    // 14.5 km north of the Kitzbühel centre (radius 12 km) → nearest() is null.
    final outside = SyntheticDayGenerator(seed: 1, lat0: 47.58, startTs: 1735288800000).generate(const [Phase.walk(70)]);
    // 400 s later, at the centre: the implied speed of the jump stays under the gate's 45 m/s.
    final inside = SyntheticDayGenerator(seed: 2, startTs: outside.pressures.last.ts + 400000).generate(const [Phase.walk(90)]);
    final h = Harness(db, startMs: outside.pressures.first.ts - 1000);
    await h.ctrl.startDay();
    final id = h.container.read(recordingControllerProvider).dayId!;
    final repo = h.container.read(daysRepositoryProvider);

    await h.feed(outside);
    await h.settle();
    expect((await repo.day(id))!.resortId, isNull, reason: 'outside every radius → not resolved, no resort written');
    expect(h.container.read(settingsProvider).lastResortId, isNull);

    h.clock.advance(inside.pressures.first.ts - 1000 - h.clock.now());
    await h.feed(inside);
    await h.settle();
    final d = await repo.day(id);
    expect(d!.resortId, 'kitzbuehel', reason: 'retry after 60 s of accepted fixes finds the resort');
    expect(d.resortName, 'Kitzbühel');
    expect(h.container.read(settingsProvider).lastResortId, 'kitzbuehel');
    expect(h.container.read(recordingControllerProvider).isRecording, isTrue);
  });
}
