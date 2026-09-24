import 'dart:async';

import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/platform/notification_service.dart';
import 'package:slopetrack/platform/permission_service.dart';
import 'package:slopetrack/platform/watchdog_channel.dart';

/// Replays fixes at [speedup]× real time (100× by default). Timestamps are kept.
class FakeLocationSource implements LocationSource {
  FakeLocationSource(this._fixes, {this.speedup = 100});
  final List<RawFix> _fixes;
  final double speedup;
  final _ctrl = StreamController<RawFix>.broadcast();
  bool _running = false;

  @override
  Stream<RawFix> get fixes => _ctrl.stream;
  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async {
    _running = true;
    int? last;
    for (final f in _fixes) {
      if (!_running) break;
      if (last != null) {
        final wait = ((f.ts - last) / speedup).round();
        if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
      }
      last = f.ts;
      _ctrl.add(f);
    }
  }

  @override
  Future<void> stop() async => _running = false;

  @override
  Future<bool> restartIfSilent(int nowMs) async => false;

  @override
  int get restartCount => 0;
}

/// Push-driven sources for deterministic controller tests.
class ManualLocationSource implements LocationSource {
  final _ctrl = StreamController<RawFix>.broadcast();
  bool _running = false;
  int restarts = 0;
  @override
  Stream<RawFix> get fixes => _ctrl.stream;
  @override
  bool get isRunning => _running;
  @override
  Future<void> start() async => _running = true;
  @override
  Future<void> stop() async => _running = false;
  @override
  Future<bool> restartIfSilent(int nowMs) async => false;
  @override
  int get restartCount => restarts;
  void push(RawFix f) => _ctrl.add(f);
}

class ManualBarometerSource implements BarometerSource {
  final _ctrl = StreamController<PressureSample>.broadcast();
  @override
  Stream<PressureSample> get samples => _ctrl.stream;
  @override
  Future<bool> get isAvailable async => true;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  void push(PressureSample s) => _ctrl.add(s);
}

class FakeBarometerSource implements BarometerSource {
  FakeBarometerSource(this._samples, {this.available = true, this.speedup = 100});
  final List<PressureSample> _samples;
  final bool available;
  final double speedup;
  final _ctrl = StreamController<PressureSample>.broadcast();
  bool _running = false;

  @override
  Stream<PressureSample> get samples => _ctrl.stream;
  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<void> start() async {
    _running = true;
    int? last;
    for (final s in _samples) {
      if (!_running) break;
      if (last != null) {
        final wait = ((s.ts - last) / speedup).round();
        if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
      }
      last = s.ts;
      _ctrl.add(s);
    }
  }

  @override
  Future<void> stop() async => _running = false;
}

class FakeBatterySource implements BatterySource {
  FakeBatterySource([this.value = 80]);
  int? value;
  @override
  Future<int?> level() async => value;
}

class NoHeartRate implements HeartRateSource {
  @override
  Stream<int> get bpm => const Stream.empty();
}

class FakePermissionService implements PermissionService {
  FakePermissionService({this.state = LocationPermissionState.always, this.precise = true, this.serviceOn = true});
  LocationPermissionState state;
  bool precise;
  bool serviceOn;
  @override
  Future<LocationPermissionState> status() async => state;
  @override
  Future<LocationPermissionState> requestWhenInUse() async => state = state == LocationPermissionState.denied ? LocationPermissionState.denied : LocationPermissionState.whileInUse;
  @override
  Future<LocationPermissionState> requestAlways() async => state = state == LocationPermissionState.whileInUse ? LocationPermissionState.always : state;
  @override
  Future<bool> requestMotion() async => true;
  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<bool> notificationsGranted() async => true;
  @override
  Future<bool> hasPreciseLocation() async => precise;
  @override
  Future<bool> requestTemporaryFullAccuracy() async => precise;
  @override
  Future<bool> isLocationServiceEnabled() async => serviceOn;
  @override
  Future<void> openSettings() async {}
}

class FakeNotificationService implements NotificationService {
  final List<(int, String, String)> shown = [];
  @override
  Future<void> init() async {}
  @override
  Future<void> showReminder(int id, String title, String body) async => shown.add((id, title, body));
  @override
  Future<void> scheduleIn(int id, Duration delay, String title, String body) async => shown.add((id, title, body));
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
}

class FakeWatchdog implements WatchdogChannel {
  bool running = false;
  bool launchedFromLocation = false;
  @override
  Future<void> start() async => running = true;
  @override
  Future<void> stop() async => running = false;
  @override
  Future<bool> didLaunchFromLocation() async => launchedFromLocation;
}
