import 'dart:collection';

import '../core/core.dart';

/// A raw state interval before validity rules and merging.
class RawInterval {
  RawInterval({required this.kind, required this.startTs, required this.endTs, this.vehicle = false});
  SegmentKind kind;
  int startTs;
  int endTs;
  bool vehicle;
  int get durationMs => endTs - startTs;
}

/// Per-tick input for the segmenter.
class SegTick {
  const SegTick({required this.ts, required this.vH, required this.h, required this.hasFix, required this.gapMs});
  final int ts;
  /// Display speed m/s (meaningless when [hasFix] is false and gap is long).
  final double vH;
  /// Fused altitude, null until available.
  final double? h;
  final bool hasFix;
  /// Milliseconds since the last accepted fix (0 when this tick has one).
  final int gapMs;
}

/// 1 Hz state machine: STOP / RUN / LIFT / OTHER / SIGNAL LOSS (docs/PLAN.md §5).
class Segmenter {
  final List<RawInterval> intervals = [];
  final Queue<(int ts, double h)> _hist = Queue();
  final Queue<bool> _runHits = Queue();

  SegmentKind _state = SegmentKind.other;
  int? _stateStart;
  int _stopTicks = 0, _moveTicks = 0, _liftTicks = 0, _liftExitTicks = 0, _flatTicks = 0, _vehicleTicks = 0, _slowTicks = 0;
  bool _vehicle = false;
  int? _gapStartTs;
  double? _gapStartH;
  int? _lastFixTs;
  int? _lastTs;
  int? _firstTs;

  SegmentKind get state => _state;
  bool get vehicle => _vehicle;
  MotionState get motionState => switch (_state) {
        SegmentKind.run => MotionState.run,
        SegmentKind.lift => MotionState.lift,
        SegmentKind.stop => MotionState.stop,
        SegmentKind.other => MotionState.other,
        SegmentKind.signalLoss => MotionState.unknown,
      };

  /// Current open interval (not yet in [intervals]).
  RawInterval? get open => _stateStart == null || _lastTs == null
      ? null
      : RawInterval(kind: _state, startTs: _stateStart!, endTs: _lastTs!, vehicle: _vehicle);

  List<RawInterval> get allIntervals => [...intervals, ?open];

  void _transition(SegmentKind next, int atTs) {
    final firstTs = _firstTs;
    if (firstTs != null && atTs < firstTs) atTs = firstTs;
    if (_stateStart != null && atTs < _stateStart!) atTs = _stateStart!;
    if (_stateStart != null && atTs > _stateStart!) {
      intervals.add(RawInterval(kind: _state, startTs: _stateStart!, endTs: atTs, vehicle: _vehicle && _state == SegmentKind.other));
    }
    _state = next;
    _stateStart = atTs;
    _stopTicks = 0;
    _moveTicks = 0;
    _liftTicks = 0;
    _liftExitTicks = 0;
    _flatTicks = 0;
    _runHits.clear();
  }

  double? _slope(int ts, int windowMs, int minSamples) {
    // Least-squares slope of h over t for samples within windowMs.
    double sx = 0, sy = 0, sxx = 0, sxy = 0;
    var n = 0;
    for (final s in _hist) {
      if (ts - s.$1 > windowMs) continue;
      final x = (s.$1 - ts) / 1000.0;
      sx += x;
      sy += s.$2;
      sxx += x * x;
      sxy += x * s.$2;
      n++;
    }
    if (n < minSamples) return null;
    final den = n * sxx - sx * sx;
    if (den.abs() < 1e-9) return null;
    return (n * sxy - sx * sy) / den;
  }

  double? _gained60(int ts, double h) {
    double? min;
    for (final s in _hist) {
      if (ts - s.$1 > 60000) continue;
      if (min == null || s.$2 < min) min = s.$2;
    }
    return min == null ? null : h - min;
  }

  void tick(SegTick t) {
    _lastTs = t.ts;
    _firstTs ??= t.ts;
    _stateStart ??= t.ts;
    final h = t.h;
    if (h != null) {
      _hist.addLast((t.ts, h));
      while (_hist.isNotEmpty && t.ts - _hist.first.$1 > 60000) {
        _hist.removeFirst();
      }
    }
    if (t.hasFix) {
      _lastFixTs = t.ts;
      _gapStartTs = null;
      _gapStartH = null;
    } else {
      _gapStartTs ??= _lastFixTs ?? t.ts;
      _gapStartH ??= h;
    }

    // ---- No fix this tick: only barometric rules apply ----
    if (!t.hasFix) {
      final gh = _gapStartH;
      final gain = (h != null && gh != null) ? h - gh : null;
      final longGap = t.gapMs > TrackingConfig.signalLossGapS * 1000;
      final baroClimb = gain != null && gain >= TrackingConfig.liftGapGainM && t.gapMs > TrackingConfig.liftGapEnterS * 1000;
      if (_state == SegmentKind.lift) {
        // Gondola: stay in LIFT while the barometer keeps rising. A barometer
        // that is flat for 60 s (hut, parked cabin) or falling during a long
        // gap ends the lift and becomes signal loss.
        final g60 = h == null ? null : _gained60(t.ts, h);
        final flat = g60 != null && g60 < 5 && _hist.length >= 30 && t.ts - _hist.first.$1 >= 55000;
        if (longGap && ((gain != null && gain <= -TrackingConfig.liftGapGainM) || flat)) {
          _transition(SegmentKind.signalLoss, flat ? t.ts - 60000 : (_lastFixTs ?? t.ts));
        }
        return;
      }
      if (baroClimb) {
        _transition(SegmentKind.lift, _gapStartTs ?? t.ts);
        return;
      }
      if (longGap && _state != SegmentKind.signalLoss) {
        _transition(SegmentKind.signalLoss, _lastFixTs ?? t.ts);
      }
      return;
    }
    if (_state == SegmentKind.signalLoss) _transition(SegmentKind.other, t.ts);

    final vH = t.vH;
    final vz10 = _slope(t.ts, 10000, 5);
    final vz30 = _slope(t.ts, 30000, 15);
    final gained60 = h == null ? null : _gained60(t.ts, h);

    // ---- Vehicle guard ----
    if (vH > TrackingConfig.vehicleSpeedMs) {
      _vehicleTicks++;
      _slowTicks = 0;
    } else {
      _vehicleTicks = 0;
      _slowTicks++;
    }
    if (!_vehicle && _vehicleTicks >= TrackingConfig.vehicleSustainS) {
      _vehicle = true;
      _transition(SegmentKind.other, t.ts - TrackingConfig.vehicleSustainS * 1000);
    }
    if (_vehicle) {
      if (_slowTicks >= 30) {
        _vehicle = false;
        _transition(SegmentKind.other, t.ts);
      }
      return;
    }

    // ---- Counters ----
    _stopTicks = vH < TrackingConfig.stopEnterSpeedMs ? _stopTicks + 1 : 0;
    _moveTicks = vH >= TrackingConfig.stopExitSpeedMs ? _moveTicks + 1 : 0;
    final liftCond = vz30 != null && vz30 >= TrackingConfig.liftEnterVz30Ms && vH <= TrackingConfig.liftMaxHorizontalSpeedMs;
    _liftTicks = liftCond ? _liftTicks + 1 : 0;
    final liftExitCond = vz30 != null && vz30 <= TrackingConfig.liftExitVz30Ms;
    _liftExitTicks = liftExitCond ? _liftExitTicks + 1 : 0;
    final runHit = vz10 != null && vz10 <= TrackingConfig.runEnterVz10Ms && vH >= TrackingConfig.runEnterSpeedMs;
    _runHits.addLast(runHit);
    while (_runHits.length > 10) {
      _runHits.removeFirst();
    }
    final runHits = _runHits.where((x) => x).length;
    final flat = vz30 != null && vz30.abs() < TrackingConfig.runFlatVz30Ms && vH < TrackingConfig.runFlatSpeedMs;
    _flatTicks = flat ? _flatTicks + 1 : 0;

    final liftEnter = (_liftTicks >= TrackingConfig.liftEnterS) ||
        (gained60 != null && gained60 >= TrackingConfig.liftEnterGained60M && vH <= TrackingConfig.liftMaxHorizontalSpeedMs);

    switch (_state) {
      case SegmentKind.lift:
        if (_liftExitTicks >= TrackingConfig.liftExitS || (vz10 != null && vz10 <= TrackingConfig.liftExitVz10Ms)) {
          _transition(SegmentKind.other, t.ts - (_liftExitTicks >= TrackingConfig.liftExitS ? TrackingConfig.liftExitS * 1000 : 0));
        }
      case SegmentKind.run:
        if (liftEnter) {
          _transition(SegmentKind.lift, t.ts - TrackingConfig.liftEnterS * 1000);
        } else if (_stopTicks >= TrackingConfig.runStopAbsorbS) {
          _transition(SegmentKind.stop, t.ts - TrackingConfig.runStopAbsorbS * 1000);
        } else if (_flatTicks >= TrackingConfig.runFlatS) {
          _transition(SegmentKind.other, t.ts - TrackingConfig.runFlatS * 1000);
        }
      case SegmentKind.stop:
        if (runHits >= TrackingConfig.runEnterHits) {
          _transition(SegmentKind.run, t.ts - 10000);
        } else if (liftEnter) {
          _transition(SegmentKind.lift, t.ts - TrackingConfig.liftEnterS * 1000);
        } else if (_moveTicks >= TrackingConfig.stopExitS) {
          _transition(SegmentKind.other, t.ts - TrackingConfig.stopExitS * 1000);
        }
      case SegmentKind.other:
      case SegmentKind.signalLoss:
        if (runHits >= TrackingConfig.runEnterHits) {
          _transition(SegmentKind.run, t.ts - 10000);
        } else if (liftEnter) {
          _transition(SegmentKind.lift, t.ts - TrackingConfig.liftEnterS * 1000);
        } else if (_stopTicks >= TrackingConfig.stopEnterS) {
          _transition(SegmentKind.stop, t.ts - TrackingConfig.stopEnterS * 1000);
        }
    }
  }
}
