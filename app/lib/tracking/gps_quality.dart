import 'dart:collection';

import '../core/core.dart';

/// Rolling 10 s median of horizontal accuracy → quality words.
class GpsQualityTracker {
  final Queue<(int ts, double hAcc)> _win = Queue();
  int? _lastAcceptedTs;

  void addAccepted(int ts, double hAccM) {
    _lastAcceptedTs = ts;
    _win.addLast((ts, hAccM));
    while (_win.isNotEmpty && ts - _win.first.$1 > 10000) {
      _win.removeFirst();
    }
  }

  void reset() {
    _win.clear();
    _lastAcceptedTs = null;
  }

  GpsQuality quality(int nowMs) {
    final last = _lastAcceptedTs;
    if (last == null || nowMs - last > TrackingConfig.gpsNoFixS * 1000 || _win.isEmpty) return GpsQuality.none;
    final sorted = _win.map((e) => e.$2).toList()..sort();
    final med = sorted[sorted.length ~/ 2];
    if (med <= TrackingConfig.gpsVeryGoodM) return GpsQuality.veryGood;
    if (med <= TrackingConfig.gpsGoodM) return GpsQuality.good;
    if (med <= TrackingConfig.gpsOkM) return GpsQuality.ok;
    return GpsQuality.weak;
  }
}
