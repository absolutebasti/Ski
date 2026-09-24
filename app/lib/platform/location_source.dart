import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../core/core.dart';

/// geolocator-backed [LocationSource] with the exact background settings from
/// docs/PLAN.md §6. Restartable; counts restarts for diagnostics.
class GeolocatorLocationSource implements LocationSource {
  GeolocatorLocationSource({this.notificationTitle = 'Aufnahme läuft', this.notificationText = 'SlopeTrack zeichnet deinen Skitag auf'});

  final String notificationTitle;
  final String notificationText;

  final _out = StreamController<RawFix>.broadcast();
  final _restarts = StreamController<int>.broadcast();
  StreamSubscription<Position>? _sub;
  int _restartCount = 0;
  int? _lastFixTs;

  @override
  Stream<RawFix> get fixes => _out.stream;
  Stream<int> get restarts => _restarts.stream;
  @override
  int get restartCount => _restartCount;
  int? get lastFixTs => _lastFixTs;

  @override
  bool get isRunning => _sub != null;

  LocationSettings get _settings {
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          enableWakeLock: true,
          setOngoing: true,
          notificationIcon: const AndroidResource(name: 'ic_notification', defType: 'drawable'),
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);
  }

  @override
  Future<void> start() async {
    if (_sub != null) return;
    _sub = Geolocator.getPositionStream(locationSettings: _settings).listen(
      (p) {
        final fix = positionToRawFix(p);
        _lastFixTs = fix.ts;
        _out.add(fix);
      },
      onError: (Object e, StackTrace st) => _out.addError(e, st),
    );
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  Future<bool> restartIfSilent(int nowMs) async {
    if (_sub == null) return false;
    final last = _lastFixTs;
    if (last != null && nowMs - last < TrackingConfig.streamWatchdogS * 1000) return false;
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    await stop();
    await start();
    _restartCount++;
    _restarts.add(_restartCount);
    return true;
  }
}

RawFix positionToRawFix(Position p) => RawFix(
      ts: p.timestamp.millisecondsSinceEpoch,
      lat: p.latitude,
      lon: p.longitude,
      hAccM: p.accuracy,
      gpsAltM: p.altitude,
      vAccM: p.altitudeAccuracy,
      speedMs: p.speed,
      speedAccMs: p.speedAccuracy,
      courseDeg: p.heading,
      isMocked: p.isMocked,
    );
