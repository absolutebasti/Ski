import 'dart:collection';

import '../core/core.dart';

/// Horizontal speed: Doppler when trusted, otherwise distance/time over ≥ 3 s;
/// display value = median-of-3 → EMA. Resets after gaps > 10 s.
class SpeedEstimator {
  final Queue<(int ts, double lat, double lon)> _pos = Queue();
  final Queue<double> _median = Queue();
  double? _ema;
  int? _lastTs;

  double get displaySpeed => _ema ?? 0;

  void reset() {
    _pos.clear();
    _median.clear();
    _ema = null;
    _lastTs = null;
  }

  /// Returns the raw (zero-clamped) speed for this fix and updates the display value.
  double update(RawFix f, {required bool speedTrusted}) {
    if (_lastTs != null && f.ts - _lastTs! > TrackingConfig.windowResetGapS * 1000) reset();
    _lastTs = f.ts;
    _pos.addLast((f.ts, f.lat, f.lon));
    while (_pos.length > 1 && f.ts - _pos.first.$1 > 5000) {
      _pos.removeFirst();
    }
    double v;
    if (speedTrusted) {
      v = f.speedMs!;
    } else if (_pos.length >= 2 && f.ts - _pos.first.$1 >= 3000) {
      final a = _pos.first;
      v = haversineM(a.$2, a.$3, f.lat, f.lon) / ((f.ts - a.$1) / 1000);
    } else {
      v = _ema ?? 0;
    }
    if (v < TrackingConfig.zeroClampMs) v = 0;
    _median.addLast(v);
    while (_median.length > 3) {
      _median.removeFirst();
    }
    final sorted = _median.toList()..sort();
    final med = sorted[sorted.length ~/ 2];
    _ema = _ema == null ? med : _ema! + TrackingConfig.displayEmaAlpha * (med - _ema!);
    return v;
  }
}

/// Confirms a max speed only when 2 of 3 consecutive candidates agree within 15 %.
class MaxSpeedTracker {
  final Queue<(double v, int ts)> _cands = Queue();
  double _max = 0;
  int? _maxTs;

  double get max => _max;
  int? get maxTs => _maxTs;

  void reset() {
    _cands.clear();
    _max = 0;
    _maxTs = null;
  }

  /// Returns true when a new confirmed maximum was set.
  bool offer(double v, int ts) {
    if (v > TrackingConfig.hardSpeedCapMs) return false;
    _cands.addLast((v, ts));
    while (_cands.length > 3) {
      _cands.removeFirst();
    }
    if (v <= _max) return false;
    final tol = v * TrackingConfig.maxSpeedConfirmTolerance;
    final agree = _cands.where((c) => (c.$1 - v).abs() <= tol).length;
    if (agree >= 2) {
      _max = v;
      _maxTs = ts;
      return true;
    }
    return false;
  }
}
