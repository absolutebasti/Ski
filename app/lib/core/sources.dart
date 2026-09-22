import 'models/models.dart';

/// Platform inputs, implemented in lib/platform (WP-03) with fakes in test/support.
abstract class LocationSource {
  /// Emits raw fixes while started. Must survive app backgrounding.
  Stream<RawFix> get fixes;
  Future<void> start();
  Future<void> stop();
  bool get isRunning;
  /// Cancel + resubscribe when no fix arrived for TrackingConfig.streamWatchdogS.
  /// Returns true if a restart happened. Default: nothing.
  Future<bool> restartIfSilent(int nowMs) async => false;
  /// Number of restarts so far (diagnostics).
  int get restartCount => 0;
}

abstract class BarometerSource {
  Stream<PressureSample> get samples;
  Future<bool> get isAvailable;
  Future<void> start();
  Future<void> stop();
}

abstract class BatterySource {
  /// 0–100, null if unknown.
  Future<int?> level();
}

/// Heart-rate input from the Apple Watch (WP-13). Phone-only builds use a no-op.
abstract class HeartRateSource {
  Stream<int> get bpm;
}
