import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/core.dart';

/// sensors_plus barometer (CMAltimeter on iOS, TYPE_PRESSURE on Android).
class SensorsBarometerSource implements BarometerSource {
  final _out = StreamController<PressureSample>.broadcast();
  StreamSubscription<BarometerEvent>? _sub;
  bool? _available;

  @override
  Stream<PressureSample> get samples => _out.stream;

  @override
  Future<bool> get isAvailable async {
    if (_available != null) return _available!;
    try {
      final first = await barometerEventStream(samplingPeriod: const Duration(seconds: 1)).first.timeout(const Duration(seconds: 4));
      _available = first.pressure > 0;
    } on TimeoutException {
      _available = false;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  @override
  Future<void> start() async {
    if (_sub != null) return;
    try {
      _sub = barometerEventStream(samplingPeriod: const Duration(seconds: 1)).listen(
        (e) => _out.add(PressureSample(ts: e.timestamp.millisecondsSinceEpoch, hPa: e.pressure)),
        onError: (Object e, StackTrace st) {
          _available = false;
        },
      );
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
