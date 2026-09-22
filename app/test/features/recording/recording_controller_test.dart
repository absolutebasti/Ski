import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/core/settings.dart';
import 'package:dropline/data/db/database.dart';
import 'package:dropline/data/db/providers.dart';
import 'package:dropline/data/resorts/resort_repository.dart';
import 'package:dropline/features/recording/recording.dart';
import 'package:dropline/platform/permission_service.dart';
import 'package:dropline/platform/providers.dart';
import 'package:dropline/tracking/synthetic.dart';

import '../../support/fakes.dart';

class Harness {
  Harness(this.db, {int startMs = 1735288800000}) : clock = FakeClock(startMs);
  final AppDatabase db;
  final FakeClock clock;
  final loc = ManualLocationSource();
  final baro = ManualBarometerSource();
  final notif = FakeNotificationService();
  final watchdog = FakeWatchdog();
  final perm = FakePermissionService();
  late final ProviderContainer container = ProviderContainer(overrides: overrides());

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        recordingClockProvider.overrideWithValue(clock),
        locationSourceProvider.overrideWithValue(loc),
        barometerSourceProvider.overrideWithValue(baro),
        batterySourceProvider.overrideWithValue(FakeBatterySource(80)),
        heartRateSourceProvider.overrideWithValue(NoHeartRate()),
        permissionServiceProvider.overrideWithValue(perm),
        notificationServiceProvider.overrideWithValue(notif),
        watchdogChannelProvider.overrideWithValue(watchdog),
        settingsProvider.overrideWith(() => SettingsNotifier(null)),
        resortRepositoryProvider.overrideWith((ref) async => ResortRepository(const [
              Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.4491, lon: 12.3913, radiusKm: 12),
            ])),
      ];

  RecordingController get ctrl => container.read(recordingControllerProvider.notifier);

  /// Feed [day] second by second from index [from] to [to] (exclusive), ticking the clock.
  Future<void> feed(SyntheticDay day, {int from = 0, int? to}) async {
    final end = to ?? day.pressures.length;
    var fi = 0;
    while (fi < day.fixes.length && day.fixes[fi].ts < day.pressures[from].ts) {
      fi++;
    }
    for (var i = from; i < end; i++) {
      final ts = day.pressures[i].ts;
      while (fi < day.fixes.length && day.fixes[fi].ts <= ts) {
        loc.push(day.fixes[fi++]);
      }
      baro.push(day.pressures[i]);
      await Future<void>.delayed(Duration.zero); // deliver stream events
      clock.advance(1000);
      if (i % 200 == 0) await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);
  }
}

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
}
