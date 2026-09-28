import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/features/recording/recording.dart';
import 'package:slopetrack/platform/notification_service.dart';
import 'package:slopetrack/platform/permission_service.dart';
import 'package:slopetrack/tracking/synthetic.dart';

import 'harness.dart';

/// Mid-day access loss, motion permission and Low Power Mode through the
/// controller (fake sources, manual clock).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // A short valid run so the day is meaningful when it auto-ends.
  SyntheticDay shortRun({int seed = 4}) => SyntheticDayGenerator(seed: seed).generate(const [Phase.stop(20), Phase.run(300, 150, avgSpeedMs: 10), Phase.stop(20)]);

  group('location service toggled off mid-day', () {
    test('access state flips, a persistent notification is shown, GPS quality follows', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      await h.ctrl.startDay();
      await h.feed(day, to: 60);
      expect(h.container.read(trackingAccessProvider).lost, isFalse);

      h.access.setService(false);
      await h.settle();
      final access = h.container.read(trackingAccessProvider);
      expect(access.access, TrackingAccess.serviceOff);
      expect(access.lostSinceMs, h.clock.now());
      expect(h.notif.shown.map((n) => n.$1), contains(NotificationIds.access));
      expect(h.notif.shown.where((n) => n.$1 == NotificationIds.access).single.$3, contains('Location services are off'));

      h.clock.advance(15000); // no fixes arrive any more
      expect(h.container.read(liveStateProvider).gps, GpsQuality.none);
      expect(h.container.read(recordingControllerProvider).isRecording, isTrue, reason: 'no auto-end before 30 min');
    });

    test('service back on → re-check clears the state and the notification', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      await h.ctrl.startDay();
      await h.feed(day, to: 40);
      h.access.setService(false);
      await h.settle();
      expect(h.container.read(trackingAccessProvider).lost, isTrue);

      h.access.setService(true);
      await h.settle();
      expect(h.container.read(trackingAccessProvider), same(TrackingAccessState.ok));
      expect(h.notif.cancelled, contains(NotificationIds.access));
      expect(h.notif.shown.where((n) => n.$1 == NotificationIds.access).length, 1, reason: 'shown once per loss');
    });

    test('30 min without access auto-ends and saves the day', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      await h.ctrl.startDay();
      final id = h.container.read(recordingControllerProvider).dayId!;
      await h.feed(day);
      h.access.setService(false);
      await h.settle();
      final lostAt = h.container.read(trackingAccessProvider).lostSinceMs!;

      h.clock.advance(kNoAccessAutoEndMin * 60000 - 1000);
      expect(h.container.read(recordingControllerProvider).isRecording, isTrue);
      h.clock.advance(2000);
      await h.settle(80);
      expect(h.container.read(recordingControllerProvider).status, RecordingStatus.idle);
      final d = await h.container.read(daysRepositoryProvider).day(id);
      expect(d!.status, DayStatus.finished);
      expect(d.endedAt, lostAt, reason: 'the dead half hour is trimmed');
      expect(h.notif.shown.last.$1, NotificationIds.summary);
      expect(h.notif.shown.last.$3, contains('30 minutes'));
      expect(h.container.read(trackingAccessProvider).lost, isFalse, reason: 'reset with the day');
    });
  });

  group('permission re-check on resume', () {
    test('permission revoked in Settings → denied state after resume', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      await h.ctrl.startDay();
      await h.feed(day, to: 30);
      h.perm.state = LocationPermissionState.denied;
      h.resumeApp();
      await h.settle();
      final access = h.container.read(trackingAccessProvider);
      expect(access.access, TrackingAccess.permissionDenied);
      expect(h.notif.shown.where((n) => n.$1 == NotificationIds.access).single.$3, contains('revoked'));
    });

    test('resume with everything fine changes nothing; granted again clears the state', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      await h.ctrl.startDay();
      await h.feed(day, to: 30);
      h.resumeApp();
      await h.settle();
      expect(h.container.read(trackingAccessProvider).lost, isFalse);
      expect(h.notif.shown.where((n) => n.$1 == NotificationIds.access), isEmpty);

      h.perm.state = LocationPermissionState.deniedForever;
      await h.ctrl.recheckAccess();
      expect(h.container.read(trackingAccessProvider).access, TrackingAccess.permissionDenied);
      h.perm.state = LocationPermissionState.whileInUse;
      await h.ctrl.recheckAccess();
      expect(h.container.read(trackingAccessProvider).lost, isFalse);
    });

    test('service off wins over permission state and the day end cancels the notification', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      await h.ctrl.startDay();
      await h.feed(day, to: 30);
      h.perm.serviceOn = false;
      await h.ctrl.recheckAccess();
      expect(h.container.read(trackingAccessProvider).access, TrackingAccess.serviceOff);
      await h.ctrl.discardDay();
      expect(h.notif.cancelled, contains(NotificationIds.access));
      expect(h.container.read(trackingAccessProvider).lost, isFalse);
    });
  });

  group('motion permission and barometer', () {
    test('motion denied → one hint at start, GPS-only altitude badge', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      h.access.motionGranted = false;
      await h.ctrl.startDay();
      expect(h.access.motionChecks, 1);
      expect(h.container.read(recordingHintsProvider).pending, [RecordingHint.motionDenied]);
      expect(h.container.read(gpsAltitudeOnlyProvider), isTrue);

      h.container.read(recordingHintsProvider.notifier).consume();
      expect(h.container.read(recordingHintsProvider).pending, isEmpty);
      h.container.read(recordingHintsProvider.notifier).push(RecordingHint.motionDenied);
      expect(h.container.read(recordingHintsProvider).pending, isEmpty, reason: 'once per recording');
      expect(h.container.read(gpsAltitudeOnlyProvider), isTrue, reason: 'badge survives the toast');
      await h.ctrl.discardDay();
      expect(h.container.read(gpsAltitudeOnlyProvider), isFalse);
    });

    test('motion granted but no pressure samples → badge after 20 s; with barometer no badge', () async {
      final noBaro = SyntheticDayGenerator(seed: 4, withBarometer: false).generate(const [Phase.walk(40)]);
      final h = Harness(db, startMs: noBaro.fixes.first.ts - 1000);
      await h.ctrl.startDay();
      expect(h.container.read(recordingHintsProvider).pending, isEmpty);
      for (final f in noBaro.fixes.take(30)) {
        h.loc.push(f);
        await Future<void>.delayed(Duration.zero);
        h.clock.advance(1000);
      }
      expect(h.container.read(liveStateProvider).stats.hasBarometer, isFalse);
      expect(h.container.read(gpsAltitudeOnlyProvider), isTrue);
      await h.ctrl.discardDay();

      final withBaro = shortRun();
      final h2 = Harness(db, startMs: withBaro.pressures.first.ts - 1000);
      await h2.ctrl.startDay();
      await h2.feed(withBaro, to: 30);
      expect(h2.container.read(liveStateProvider).stats.hasBarometer, isTrue);
      expect(h2.container.read(gpsAltitudeOnlyProvider), isFalse);
    });
  });

  group('Low Power Mode', () {
    test('polled with the battery sample: hint once at start, diagnostics field set', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      h.access.lowPower = true;
      expect(h.container.read(lowPowerModeProvider), isNull);
      await h.ctrl.startDay();
      await h.feed(day, to: 3);
      expect(h.container.read(lowPowerModeProvider), isTrue);
      expect(h.container.read(recordingHintsProvider).pending, [RecordingHint.lowPowerMode]);
      h.container.read(recordingHintsProvider.notifier).consume();

      // next sample 5 min later: still on, but the hint does not repeat
      h.clock.advance(TrackingConfig.batterySampleMin * 60000 + 1000);
      await h.settle();
      expect(h.access.lowPowerChecks, 2);
      expect(h.container.read(recordingHintsProvider).pending, isEmpty);
      expect(h.container.read(recordingHintsProvider).raised, {RecordingHint.lowPowerMode});
      expect(h.container.read(lowPowerModeProvider), isTrue);

      h.access.lowPower = false;
      h.clock.advance(TrackingConfig.batterySampleMin * 60000 + 1000);
      await h.settle();
      expect(h.container.read(lowPowerModeProvider), isFalse);
    });

    test('normal mode: no hint, field false after the first sample', () async {
      final day = shortRun();
      final h = Harness(db, startMs: day.pressures.first.ts - 1000);
      await h.ctrl.startDay();
      await h.feed(day, to: 3);
      expect(h.container.read(lowPowerModeProvider), isFalse);
      expect(h.container.read(recordingHintsProvider).raised, isEmpty);
    });
  });
}
