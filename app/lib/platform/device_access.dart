import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Runtime signals a recording has to react to mid-day: location services
/// switched off, Motion & Fitness revoked (no barometer on iOS), Low Power
/// Mode. Separate from [PermissionService] so its fakes stay untouched.
abstract class DeviceAccessSource {
  /// Emits whenever the system location service is toggled (true = enabled).
  /// Never errors; an unsupported platform yields an empty stream.
  Stream<bool> get locationServiceChanges;

  /// iOS Motion & Fitness granted (CMAltimeter needs it). Android: always true.
  Future<bool> isMotionGranted();

  /// iOS Low Power Mode / Android Battery Saver.
  Future<bool> isLowPowerMode();
}

/// geolocator + permission_handler + battery_plus. Every call swallows plugin
/// errors and falls back to "nothing wrong" so a missing plugin (tests, desktop)
/// never blocks a recording.
class PluginDeviceAccessSource implements DeviceAccessSource {
  final _battery = Battery();

  @override
  Stream<bool> get locationServiceChanges {
    late StreamController<bool> out;
    StreamSubscription<ServiceStatus>? sub;
    out = StreamController<bool>(
      onListen: () {
        try {
          sub = Geolocator.getServiceStatusStream().listen(
            (s) => out.add(s == ServiceStatus.enabled),
            onError: (Object _) {},
          );
        } catch (_) {}
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<bool> isMotionGranted() async {
    if (!Platform.isIOS) return true;
    try {
      final s = await ph.Permission.sensors.status;
      return s.isGranted || s.isLimited || s.isProvisional;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> isLowPowerMode() async {
    try {
      return await _battery.isInBatterySaveMode;
    } catch (_) {
      return false;
    }
  }
}
