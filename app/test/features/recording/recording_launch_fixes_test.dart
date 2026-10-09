import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/features/recording/recording.dart';
import 'package:slopetrack/platform/permission_service.dart';
import 'package:slopetrack/tracking/synthetic.dart';

import 'harness.dart';

/// Launch audit 2026-10-09: restart merge, expired days, "Allow Once",
/// trailing-idle trim, watchdog shutdown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const morning = [Phase.stop(30), Phase.lift(300, 300), Phase.run(300, 150), Phase.stop(30)];

  Future<String> recordAndEnd(Harness h, SyntheticDay day) async {
    await h.ctrl.startDay();
    await h.feed(day);
    final id = await h.ctrl.endDay();
    expect(id, isNotNull);
    return id!;
  }

  test('Start 3.5 h after End continues the day and keeps recording', () async {
    final day = SyntheticDayGenerator(seed: 7).generate(morning);
    final h = Harness(db, startMs: day.pressures.first.ts - 1000);
    final id = await recordAndEnd(h, day);

    h.clock.advance(const Duration(minutes: 210).inMilliseconds);
    await h.ctrl.startDay();
    expect(h.container.read(recordingControllerProvider).dayId, id, reason: 'restart merge');
    final rest = SyntheticDayGenerator(seed: 8, startTs: h.clock.now()).generate(const [Phase.stop(30)]);
    await h.feed(rest);
    await h.settle();
    expect(h.container.read(recordingControllerProvider).isRecording, isTrue, reason: 'idle counts from the new session, not from the morning run');
  });

  test('Start far away from where the last day ended begins a new day', () async {
    final day = SyntheticDayGenerator(seed: 7).generate(morning);
    final h = Harness(db, startMs: day.pressures.first.ts - 1000);
    final id = await recordAndEnd(h, day);

    h.clock.advance(const Duration(hours: 1).inMilliseconds);
    // ~45 km south: another resort.
    h.loc.lastKnownFix = RawFix(ts: h.clock.now(), lat: 47.05, lon: 12.39, hAccM: 5);
    await h.ctrl.startDay();
    expect(h.container.read(recordingControllerProvider).dayId, isNot(id));
  });

  test('a day from yesterday is finished at boot, not resumed', () async {
    final day = SyntheticDayGenerator(seed: 7).generate();
    final h1 = Harness(db, startMs: day.pressures.first.ts - 1000);
    await h1.ctrl.startDay();
    await h1.feed(day, to: 900);
    final activeId = h1.container.read(recordingControllerProvider).dayId!;
    h1.container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final h2 = Harness(db, startMs: day.pressures[900].ts + const Duration(hours: 20).inMilliseconds);
    h2.watchdog.launchedFromLocation = true;
    h2.watchdog.running = true;
    expect(await h2.ctrl.resumeIfActive(), isFalse);
    final d = await h2.container.read(daysRepositoryProvider).day(activeId);
    expect(d!.status, DayStatus.finished);
    expect(d.endedAt! - d.startedAt, lessThan(const Duration(hours: 16).inMilliseconds));
    expect(h2.watchdog.running, isFalse);
    expect(await h2.container.read(recoveryProvider.future), isNull);
  });

  test('Start next to the recovery card continues today\'s interrupted day', () async {
    final day = SyntheticDayGenerator(seed: 3).generate();
    final h1 = Harness(db, startMs: day.pressures.first.ts - 1000);
    await h1.ctrl.startDay();
    await h1.feed(day, to: 900);
    final activeId = h1.container.read(recordingControllerProvider).dayId!;
    h1.container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final h2 = Harness(db, startMs: day.pressures[900].ts + const Duration(hours: 2).inMilliseconds);
    expect(await h2.ctrl.resumeIfActive(), isFalse);
    await h2.ctrl.startDay();
    expect(h2.container.read(recordingControllerProvider).dayId, activeId);
    expect(await h2.container.read(daysRepositoryProvider).activeDay(), isNotNull);
  });

  test('discarding a recovered day stops the location watchdog', () async {
    final day = SyntheticDayGenerator(seed: 3).generate();
    final h1 = Harness(db, startMs: day.pressures.first.ts - 1000);
    await h1.ctrl.startDay();
    await h1.feed(day, to: 900);
    final activeId = h1.container.read(recordingControllerProvider).dayId!;
    h1.container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final h2 = Harness(db, startMs: day.pressures[900].ts + const Duration(hours: 2).inMilliseconds);
    h2.watchdog.running = true;
    await h2.ctrl.discardRecoveredDay(activeId);
    expect(h2.watchdog.running, isFalse);
  });

  test('"Allow Once" expired: Start asks again instead of failing', () async {
    final h = Harness(db);
    h.perm
      ..state = LocationPermissionState.denied
      ..askable = true;
    await h.ctrl.startDay();
    expect(h.container.read(recordingControllerProvider).isRecording, isTrue);
  });

  test('a trimmed auto-end stores numbers only up to the trim point', () async {
    final day = SyntheticDayGenerator(seed: 7).generate([...morning, const Phase.stop(1200)]);
    final h = Harness(db, startMs: day.pressures.first.ts - 1000);
    await h.ctrl.startDay();
    await h.feed(day);
    final trimAt = day.pressures[day.pressures.length - 1100].ts;
    final id = await h.ctrl.endDay(trimTrailingIdleFrom: trimAt);
    final repo = h.container.read(daysRepositoryProvider);
    final d = await repo.day(id!);
    expect(d!.endedAt, trimAt);
    final points = await repo.pointsRaw(id);
    expect(points.last.ts, lessThanOrEqualTo(trimAt));
    expect(d.stats.elapsedMs, lessThanOrEqualTo(trimAt - points.first.ts + 1000));
  });
}
