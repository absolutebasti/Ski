import 'package:battery_plus/battery_plus.dart';

import '../core/core.dart';

class BatteryPlusSource implements BatterySource {
  final _battery = Battery();
  @override
  Future<int?> level() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }
}

/// Phone-only builds: no heart rate. WP-13 replaces this via provider override.
class NoopHeartRateSource implements HeartRateSource {
  @override
  Stream<int> get bpm => const Stream.empty();
}
