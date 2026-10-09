import 'dart:collection';

import '../core/core.dart';

/// A raw state interval before validity rules and merging.
class RawInterval {
  RawInterval({required this.kind, required this.startTs, required this.endTs, this.vehicle = false, this.cable = false});
  SegmentKind kind;
  int startTs;
  int endTs;
  bool vehicle;
  /// Set by finalize's cable post-pass: the cable signature covers this
  /// interval, so it is a lift ride even when it goes *down* into the valley.
  bool cable;
  int get durationMs => endTs - startTs;
}

/// Per-tick input for the segmenter.
class SegTick {
  const SegTick({
    required this.ts,
    required this.vH,
    required this.h,
    required this.hasFix,
    required this.gapMs,
    this.cableHolds = false,
    this.cableRides = false,
    this.cableVetoRun = false,
    this.deadGap = false,
    this.deadGapKind = SegmentKind.signalLoss,
  });
  final int ts;
  /// Display speed m/s (meaningless when [hasFix] is false and gap is long).
  final double vH;
  /// Fused altitude, null until available.
  final double? h;
  final bool hasFix;
  /// Milliseconds since the last accepted fix (0 when this tick has one).
  final int gapMs;
  /// Loose cable signature (CableDetector.holdsAt): constant speed, straight,
  /// altitude one way *or* flat. Holds a running LIFT together over a cable
  /// car's flat mid-span and over the stretch where a chairlift dips.
  final bool cableHolds;
  /// Strict cable signature (CableDetector.ridesAt) — **ascending only**: the
  /// loose test plus a real altitude *gain* on a real gradient. Opens a LIFT.
  /// A ride down is never opened here; `descent.dart` decides that afterwards
  /// from a station at both ends, three minutes and 120 m of drop.
  final bool cableRides;
  /// CableDetector.vetoesRunAt: [cableHolds] minus the descending case. A window
  /// losing height at a constant speed on a straight line is what a schuss looks
  /// like, so it must not stop a RUN from starting — that was the bug that made
  /// a steady 5–11 m/s descent disappear from the day.
  final bool cableVetoRun;
  /// Nothing at all (no fix, no barometer) reached the segmenter for longer
  /// than signalLossGapS — the app was not running or the phone was off. The
  /// gap is SIGNAL LOSS whatever the state, so an open RUN or LIFT never
  /// stretches over it.
  final bool deadGap;
  /// What the dead gap becomes: STOP when the rider is back where the gap
  /// began, SIGNAL LOSS otherwise.
  final SegmentKind deadGapKind;
}

/// 1 Hz state machine: STOP / RUN / LIFT / OTHER / SIGNAL LOSS (docs/PLAN.md §5).
class Segmenter {
  final List<RawInterval> intervals = [];
  final Queue<(int ts, double h)> _hist = Queue();
  final Queue<bool> _runHits = Queue();

  SegmentKind _state = SegmentKind.other;
  int? _stateStart;
  int _stopTicks = 0, _moveTicks = 0, _liftTicks = 0, _liftExitTicks = 0, _flatTicks = 0, _vehicleTicks = 0, _slowTicks = 0;
  int _cableTicks = 0;
  bool _vehicle = false;
  int? _gapStartTs;
  double? _gapStartH;
  int? _lastFixTs;
  int? _lastTs;
  int? _firstTs;

  SegmentKind get state => _state;
  bool get vehicle => _vehicle;
  /// Timestamp of the last tick seen (any kind), null before the first.
  int? get lastTickTs => _lastTs;
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
    _cableTicks = 0;
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
    if (!t.hasFix && t.deadGap) {
      if (_state != t.deadGapKind) _transition(t.deadGapKind, _lastFixTs ?? t.ts);
      _gapStartTs = t.ts;
      _gapStartH = null;
      return;
    }
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
          // New baseline: only a fresh +30 m from here is another lift, else the
          // old gain re-enters LIFT on the very next tick (flip-flop).
          _gapStartTs = t.ts;
          _gapStartH = h;
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
    // The interval being closed carries the flag that was valid *during* it:
    // close first, then toggle, so the vehicle ride itself is the flagged one.
    if (!_vehicle && _vehicleTicks >= TrackingConfig.vehicleSustainS) {
      _transition(SegmentKind.other, t.ts - TrackingConfig.vehicleSustainS * 1000);
      _vehicle = true;
    }
    if (_vehicle) {
      if (_slowTicks >= 30) {
        _transition(SegmentKind.other, t.ts);
        _vehicle = false;
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

    _cableTicks = t.cableRides ? _cableTicks + 1 : 0;
    // A confirmed cable ride is a lift whatever the barometer says: it catches
    // the T-bar (too shallow for vz30), the funicular (too fast for
    // liftMaxHorizontalSpeedMs) and the gondola riding *down* into the valley
    // (which otherwise passes the RUN entry rule at 25 km/h).
    final cableEnter = _cableTicks >= TrackingConfig.cableEnterS;
    final liftEnter = cableEnter ||
        (_liftTicks >= TrackingConfig.liftEnterS) ||
        (gained60 != null && gained60 >= TrackingConfig.liftEnterGained60M && vH <= TrackingConfig.liftMaxHorizontalSpeedMs);

    switch (_state) {
      case SegmentKind.lift:
        // While the cable signature holds, neither exit may fire: that keeps a
        // cable car's flat mid-span inside one ride, and it is what stops a
        // *descending* ride from leaving LIFT on the very next tick (vz10 is
        // strongly negative all the way down).
        if (!t.cableHolds &&
            (_liftExitTicks >= TrackingConfig.liftExitS || (vz10 != null && vz10 <= TrackingConfig.liftExitVz10Ms))) {
          _transition(SegmentKind.other, t.ts - (_liftExitTicks >= TrackingConfig.liftExitS ? TrackingConfig.liftExitS * 1000 : 0));
        }
      case SegmentKind.run:
        if (cableEnter) {
          _transition(SegmentKind.lift, t.ts - TrackingConfig.cableEnterS * 1000);
        } else if (liftEnter) {
          _transition(SegmentKind.lift, t.ts - TrackingConfig.liftEnterS * 1000);
        } else if (_stopTicks >= TrackingConfig.runStopAbsorbS) {
          _transition(SegmentKind.stop, t.ts - TrackingConfig.runStopAbsorbS * 1000);
        } else if (_flatTicks >= TrackingConfig.runFlatS) {
          _transition(SegmentKind.other, t.ts - TrackingConfig.runFlatS * 1000);
        }
      case SegmentKind.stop:
        if (runHits >= TrackingConfig.runEnterHits && !t.cableVetoRun) {
          _transition(SegmentKind.run, t.ts - 10000);
        } else if (liftEnter) {
          _transition(SegmentKind.lift, t.ts - TrackingConfig.liftEnterS * 1000);
        } else if (_moveTicks >= TrackingConfig.stopExitS) {
          _transition(SegmentKind.other, t.ts - TrackingConfig.stopExitS * 1000);
        }
      case SegmentKind.other:
      case SegmentKind.signalLoss:
        if (runHits >= TrackingConfig.runEnterHits && !t.cableVetoRun) {
          _transition(SegmentKind.run, t.ts - 10000);
        } else if (liftEnter) {
          _transition(SegmentKind.lift, t.ts - TrackingConfig.liftEnterS * 1000);
        } else if (_stopTicks >= TrackingConfig.stopEnterS) {
          _transition(SegmentKind.stop, t.ts - TrackingConfig.stopEnterS * 1000);
        }
    }
  }
}
