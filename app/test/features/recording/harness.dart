import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/data/resorts/resort_repository.dart';
import 'package:slopetrack/features/recording/recording.dart';
import 'package:slopetrack/platform/device_access.dart';
import 'package:slopetrack/platform/providers.dart';
import 'package:slopetrack/tracking/synthetic.dart';

import '../../support/fakes.dart';

/// Push-driven access signals (service toggle, motion permission, Low Power).
class FakeDeviceAccess implements DeviceAccessSource {
  final _service = StreamController<bool>.broadcast();
  bool motionGranted = true;
  bool lowPower = false;
  int motionChecks = 0;
  int lowPowerChecks = 0;

  @override
  Stream<bool> get locationServiceChanges => _service.stream;

  @override
  Future<bool> isMotionGranted() async {
    motionChecks++;
    return motionGranted;
  }

  @override
  Future<bool> isLowPowerMode() async {
    lowPowerChecks++;
    return lowPower;
  }

  /// Simulates the system toggling location services.
  void setService(bool enabled) => _service.add(enabled);
}

/// Records cancellations too (the shared fake only records shows).
class TrackingNotifications extends FakeNotificationService {
  final List<int> cancelled = [];
  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// Controller under test with every platform input faked and a manual clock.
class Harness {
  Harness(this.db, {int startMs = 1735288800000}) : clock = FakeClock(startMs) {
    addTearDown(close);
  }
  final AppDatabase db;
  final FakeClock clock;
  final loc = ManualLocationSource();
  final baro = ManualBarometerSource();
  final notif = TrackingNotifications();
  final watchdog = FakeWatchdog();
  final perm = FakePermissionService();
  final access = FakeDeviceAccess();
  final battery = FakeBatterySource(80);
  late final ProviderContainer container = ProviderContainer(overrides: overrides());

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        recordingClockProvider.overrideWithValue(clock),
        locationSourceProvider.overrideWithValue(loc),
        barometerSourceProvider.overrideWithValue(baro),
        batterySourceProvider.overrideWithValue(battery),
        heartRateSourceProvider.overrideWithValue(NoHeartRate()),
        permissionServiceProvider.overrideWithValue(perm),
        notificationServiceProvider.overrideWithValue(notif),
        watchdogChannelProvider.overrideWithValue(watchdog),
        deviceAccessProvider.overrideWithValue(access),
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

  /// Test teardown: discard an open day so no write is in flight when the
  /// in-memory database closes (an uncaught late write would fail the *next*
  /// test). Safe after a simulated kill (container already disposed).
  Future<void> close() async {
    try {
      if (container.read(recordingControllerProvider).isRecording) await ctrl.discardDay();
    } catch (_) {}
    await settle();
    container.dispose();
  }

  /// Lets pending async work (stream events, DB writes, endDay) complete.
  Future<void> settle([int ms = 30]) => Future<void>.delayed(Duration(milliseconds: ms));

  /// Background → foreground round trip as the app sees it.
  void resumeApp() {
    final b = TestWidgetsFlutterBinding.instance;
    b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}
