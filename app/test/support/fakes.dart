import 'dart:async';

import 'package:schwung/core/core.dart';

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
