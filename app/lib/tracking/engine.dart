import 'dart:math' as math;

import '../core/core.dart';
import 'altitude.dart';
import 'cable.dart';
import 'descent.dart';
import 'finalize.dart';
import 'gate.dart';
import 'gps_quality.dart';
import 'segmenter.dart';
import 'speed.dart';
import 'vertical.dart';

/// Output of one engine tick.
class EngineTick {
  const EngineTick({required this.point, required this.live, required this.newSegments, required this.segmentsChanged});
  /// Null when the tick carried no new data (nothing to persist).
  final TrackPoint? point;
  final LiveState live;
  /// Segments finalized since the previous tick (may be empty).
  final List<Segment> newSegments;
  final bool segmentsChanged;
}

/// Segments + stats for a whole day.
class DayComputation {
  const DayComputation({required this.segments, required this.stats, required this.points});
  final List<Segment> segments;
  final DayStats stats;
  final List<TrackPoint> points;
}

/// Pure-Dart tracking engine driven by [tick] at ≈1 Hz. Feed fixes and pressure
/// samples as they arrive; each tick merges the newest of both into one
/// [TrackPoint], runs gate → altitude → speed → segmenter → stats.
/// `computeDay` replays the same code offline, so live == offline.
class TrackingEngine {
  TrackingEngine({required this.dayId});

  final String dayId;
  final FixGate _gate = FixGate();
  final SpeedEstimator _speed = SpeedEstimator();
  final BaroFilter _baro = BaroFilter();
  final AltitudeFuser _alt = AltitudeFuser();
  final GpsQualityTracker _gps = GpsQualityTracker();
  final Segmenter _segmenter = Segmenter();
  final CableDetector _cable = CableDetector();
  /// The descent the skier might currently be on (see [_liveMaxSpeed]). Only fed
  /// while [TrackingConfig.descentRidesEnabled]: with the descending rule off no
  /// descent is ever reclassified, so holding a peak back would only ever make
  /// the live number lag behind a final number that keeps it.
  final DescentCandidate _descent = DescentCandidate();
  /// Start of the open RUN interval while it already looks like the ski bus (see
  /// [TrackingConfig.roadLiveMinDurationS]); null when nothing is held.
  int? _roadHoldFrom;
  int _roadCheckedTs = 0;
  /// Start of the open RUN interval while that run is still too short to survive
  /// [TrackingConfig.runMinDurationS]; null when nothing is held. See
  /// [_updateShortRunHold].
  int? _shortRunHoldFrom;
  /// Last tick whose display speed was above the segmenter's stop threshold.
  int? _lastMovingTs;
  VerticalAccumulator? _vertical;

  final List<TrackPoint> points = [];
  /// Accepted points with a fused altitude — what the descent evidence reads.
  final List<TrackPoint> _accepted = [];
  final PointAggregate _agg = PointAggregate();
  List<Segment> _segments = const [];
  DayStats _stats = DayStats.empty;
  LiveState _live = LiveState.empty;

  /// Frozen head of [_segments] after the last full recompute (see [_recompute]).
  List<Segment> _prefix = const [];
  int _prefixRuns = 0;
  /// Raw-interval boundary the provisional tail is rebuilt from (see [_freezePrefix]).
  int? _tailFromTs;
  int _fullRecomputes = 0;
  int _recomputes = 0;

  RawFix? _pendingFix;
  PressureSample? _pendingPressure;
  int? _pendingHr;
  int? _lastAcceptedTs;
  /// Position of the last accepted fix (dead-gap pause vs. signal loss).
  RawFix? _lastAcceptedFix;
  int? _lastTickTs;
  int _ticksSinceRecompute = 0;
  int _finalizedCount = 0;
  int? _batteryPct;
  int? _batteryEtaTs;

  List<Segment> get segments => _segments;
  DayStats get stats => _stats;
  LiveState get live => _live;
  bool get hasBarometer => _alt.hasBarometer;

  void addFix(RawFix f) => _pendingFix = f;
  void addPressure(PressureSample s) => _pendingPressure = s;
  void addHeartRate(int bpm) => _pendingHr = bpm;
  void setBattery({int? pct, int? etaTs}) {
    _batteryPct = pct;
    _batteryEtaTs = etaTs;
  }

  /// Advance one tick. Call at 1 Hz with the wall clock (live) or at each point's ts (replay).
  EngineTick tick(int nowMs) {
    final fix = _pendingFix;
    _pendingFix = null;
    PressureSample? pressure;
    PressureSample? rawPressure;
    final pp = _pendingPressure;
    if (pp != null && nowMs - pp.ts <= TrackingConfig.baroMaxAgeS * 1000) {
      rawPressure = pp;
      pressure = _baro.filter(pp);
      _pendingPressure = null;
    }
    final hr = _pendingHr;
    _pendingHr = null;

    if (fix == null && rawPressure == null && hr == null) {
      _refreshLive(nowMs, hasFix: false);
      return EngineTick(point: null, live: _live, newSegments: const [], segmentsChanged: false);
    }

    double? fused;
    if (pressure != null) fused = _alt.addPressure(pressure);

    var accepted = false;
    var reason = RejectReason.none;
    RawFix? prevAccepted;
    double rawSpeed = 0;
    GateResult? g;
    if (fix != null) {
      g = _gate.evaluate(fix, nowMs);
      accepted = g.accepted;
      reason = g.reason;
      if (accepted) {
        prevAccepted = _lastAcceptedFix;
        _lastAcceptedTs = fix.ts;
        _lastAcceptedFix = fix;
        _gps.addAccepted(fix.ts, fix.hAccM);
        fused = _alt.addFix(fix, altAnchor: g.altAnchor, nowMs: nowMs) ?? fused;
        rawSpeed = _speed.update(fix, speedTrusted: g.speedTrusted);
      }
    }
    fused ??= _alt.value;
    if (fused != null) {
      _vertical ??= VerticalAccumulator(hasBarometer: _alt.hasBarometer);
      _vertical!.update(fused);
    }

    final ts = fix?.ts ?? nowMs;
    final gapMs = _lastAcceptedTs == null ? 0 : ts - _lastAcceptedTs!;
    // The cable window sees every accepted fix *before* the segmenter tick, so
    // the verdict a tick is judged on is the one that includes this fix — the
    // same order the offline replay and finalize's post-pass see.
    if (accepted && fix != null && fused != null) {
      _cable.add(ts: ts, lat: fix.lat, lon: fix.lon, altM: fused, speedMs: fix.speedMs, speedAccMs: fix.speedAccMs);
    }
    final before = _segmenter.intervals.length;
    // Dead gap: no tick at all for longer than signal loss allows (app not
    // running, phone off, no barometer). Back where it stopped = a pause
    // (Start again after lunch); anywhere else = signal loss. Live and replay
    // see the same fixes, so both mark it the same way.
    final segLast = _segmenter.lastTickTs;
    if (segLast != null && ts - segLast > TrackingConfig.signalLossGapS * 1000) {
      final samePlace = accepted && fix != null && prevAccepted != null &&
          haversineM(prevAccepted.lat, prevAccepted.lon, fix.lat, fix.lon) <= TrackingConfig.deadGapPauseM;
      _segmenter.tick(SegTick(ts: ts - 1, vH: 0, h: null, hasFix: false, gapMs: ts - segLast,
          deadGap: true, deadGapKind: samePlace ? SegmentKind.stop : SegmentKind.signalLoss));
    }
    _segmenter.tick(SegTick(
      ts: ts,
      vH: _speed.displaySpeed,
      h: fused,
      hasFix: accepted,
      gapMs: accepted ? 0 : gapMs,
      cableHolds: _cable.holdsAt(ts),
      cableRides: _cable.ridesAt(ts),
      cableVetoRun: _cable.vetoesRunAt(ts),
    ));
    final intervalsChanged = _segmenter.intervals.length != before;

    final point = TrackPoint(
      ts: ts,
      lat: fix?.lat, lon: fix?.lon, hAccM: fix?.hAccM, gpsAltM: fix?.gpsAltM, vAccM: fix?.vAccM,
      speedMs: fix?.speedMs, // raw Doppler as received; estimators recompute on replay
      speedAccMs: fix?.speedAccMs, courseDeg: fix?.courseDeg,
      pressureHpa: rawPressure?.hPa, fusedAltM: fused,
      accepted: accepted, rejectReason: reason,
      state: accepted ? _segmenter.motionState : MotionState.unknown,
      heartRateBpm: hr,
    );
    points.add(point);
    if (accepted && fused != null && point.hasPosition) _accepted.add(point);
    _agg.add(point);
    _lastTickTs = ts;
    if (_speed.displaySpeed >= TrackingConfig.stopEnterSpeedMs) _lastMovingTs = ts;
    // A descending cable ride cannot be read off a 45 s window, so the live top
    // speed has to be told *which* peaks are still provisional: everything
    // stamped inside a descent that may yet turn out to be a cabin ride. The
    // candidate opens at a standstill and dies the moment the evidence breaks.
    if (TrackingConfig.descentRidesEnabled) {
      _descent.update(ts: ts, descending: _segmenter.state == SegmentKind.run, speedMs: accepted ? rawSpeed : null, points: _accepted);
    }

    _ticksSinceRecompute++;
    var newSegs = const <Segment>[];
    var changed = false;
    if (intervalsChanged || _ticksSinceRecompute >= 5) {
      _recompute(full: intervalsChanged);
      _ticksSinceRecompute = 0;
      if (_segments.length > _finalizedCount || intervalsChanged) {
        changed = true;
        newSegs = _segments.skip(_finalizedCount).where((s) => s.endTs <= (_segmenter.open?.startTs ?? s.endTs)).toList();
        _finalizedCount = _segments.length;
      }
    }
    _updateRoadHold(ts);
    _updateShortRunHold(ts);
    _refreshLive(nowMs, hasFix: accepted);
    return EngineTick(point: point, live: _live, newSegments: newSegs, segmentsChanged: changed);
  }

  /// Segments + stats. A *full* recompute (state transition, [finish]) runs the
  /// finalize rules over the whole day and then freezes a prefix; the 5-tick live
  /// refresh only re-finalizes the tail behind it, so per-tick cost stays bounded
  /// over a 10 h day instead of growing with the point count. The tail is
  /// provisional; the next transition (or [finish]) recomputes everything.
  ///
  /// The tail is handed **whole raw intervals**, never a clipped one. A clipped
  /// interval is a different interval: its cable start snap walks to a different
  /// place, its ascent has no station in front of it any more, and its speed
  /// spread is measured over a different window — so the splice would stop
  /// agreeing with a full pass. [_freezePrefix] therefore cuts at a raw interval
  /// boundary (see there), and this method only *selects*, never trims.
  void _recompute({bool full = true}) {
    _recomputes++;
    final all = _segmenter.allIntervals;
    if (full || _tailFromTs == null) {
      _fullRecomputes++;
      _segments = finalizeSegments(all, points, dayId: dayId);
      _freezePrefix();
    } else {
      final cut = _tailFromTs!;
      final tail = <RawInterval>[];
      for (final r in all) {
        if (r.endTs <= cut) continue;
        tail.add(RawInterval(kind: r.kind, startTs: r.startTs, endTs: r.endTs, vehicle: r.vehicle));
      }
      final from = lowerBoundTs(points, cut - TrackingConfig.finalizeLookbackS * 1000);
      final tailSegs = finalizeSegments(tail, points.sublist(from), dayId: dayId, firstIdx: _prefix.length, firstRunNumber: _prefixRuns + 1);
      _segments = [..._prefix, ...tailSegs];
    }
    _stats = dayStatsFrom(_segments, _agg, hasBarometer: _alt.hasBarometer);
  }

  /// Freezes the head of [_segments] that no later pass can touch.
  ///
  /// Three things have to be true of the cut, and the third is what round 2 got
  /// wrong (finding C):
  ///
  /// 1. it lies at least [TrackingConfig.finalizeLookbackS] before the open
  ///    interval, which is derived from the reach of every finalize rule — the
  ///    60 s turning-point snap, the 80 s cable start snap, and the descending
  ///    carve's 1.925 s when [TrackingConfig.descentRidesEnabled] is on;
  /// 2. it lies on a **raw interval boundary**, so the tail never judges a
  ///    clipped interval (see [_recompute]);
  /// 3. it lies two intervals further back still. Rule 3b moves the boundary
  ///    *between* two intervals and needs the one in front; rule 1c walks a
  ///    ride's start back over its neighbour. One spare interval for each.
  ///
  /// The cost is that the tail is longer than a fixed 90 s window would make it —
  /// bounded by two intervals plus the lookback, not by the day.
  void _freezePrefix() {
    final open = _segmenter.open;
    void clear() {
      _prefix = const [];
      _prefixRuns = 0;
      _tailFromTs = null;
    }

    if (open == null) {
      clear();
      return;
    }
    final base = open.startTs - TrackingConfig.finalizeLookbackS * 1000;
    final all = _segmenter.allIntervals;
    var k = all.length - 1;
    while (k > 0 && all[k].startTs > base) {
      k--;
    }
    k -= 2; // one spare for rule 3b, one for the start snap
    // …and the prefix has to end *exactly* where the tail begins, or the day gets
    // a hole. The snaps move segment boundaries away from the raw interval
    // boundaries they came from — rule 3b pulls a run's start back over the
    // OTHER sliver in front of it, so the segment ends 27 s before the interval
    // does — and a hole is 27 s of skiing that the live screen does not count.
    // Step back until interval boundary and segment boundary coincide.
    while (k > 0) {
      final cut = all[k].startTs;
      var n = 0;
      var runs = 0;
      for (final s in _segments) {
        if (s.endTs > cut) break;
        n++;
        if (s.kind == SegmentKind.run) runs++;
      }
      if (n > 0 && _segments[n - 1].endTs == cut) {
        _prefix = _segments.sublist(0, n);
        _prefixRuns = runs;
        _tailFromTs = cut;
        return;
      }
      k--;
    }
    clear();
  }

  /// The top speed the screen may show right now.
  ///
  /// Not [_stats.maxSpeedMs]: that is the max over the RUN segments *including*
  /// the provisional open one, and a gondola riding down is still a RUN there
  /// until the evidence for the ride is complete. A peak stamped inside a live
  /// descent candidate is therefore held back — unless it is faster than any
  /// cable, in which case it is skiing for certain and must not lag. Nothing
  /// sticky: when finalize takes a segment away, the number goes with it.
  double _liveMaxSpeed() {
    var hold = TrackingConfig.descentRidesEnabled ? _descent.holdFrom : null;
    for (final h in [_roadHoldFrom, _shortRunHoldFrom]) {
      if (h == null) continue;
      hold = hold == null ? h : math.min(hold, h);
    }
    var m = 0.0;
    for (final s in _segments) {
      if (s.kind != SegmentKind.run || s.maxSpeedMs <= m) continue;
      final at = s.maxSpeedAtTs;
      if (hold != null && at != null && at >= hold && s.maxSpeedMs <= TrackingConfig.cableMaxSpeedMs) continue;
      m = s.maxSpeedMs;
    }
    return m;
  }

  /// The road guard cannot classify before [TrackingConfig.roadMinDurationS], and
  /// until then the bus's 40 km/h sits on the screen as a top speed the finished
  /// day throws away. From [TrackingConfig.roadLiveMinDurationS] on, the *same*
  /// geometry (both hairpins included) is asked of the open interval and its
  /// peaks are held back. Nothing is reclassified early; only the number waits.
  /// Evaluated at most once a second, over the open interval only.
  void _updateRoadHold(int ts) {
    final open = _segmenter.open;
    if (open == null || open.kind != SegmentKind.run) {
      _roadHoldFrom = null;
      return;
    }
    if (open.durationMs < TrackingConfig.roadLiveMinDurationS * 1000) {
      _roadHoldFrom = null;
      return;
    }
    if (_roadHoldFrom == open.startTs) return; // already held, nothing changes
    if (ts - _roadCheckedTs < 1000) return;
    _roadCheckedTs = ts;
    _roadHoldFrom = isRoadDescent(_accepted, open.startTs, open.endTs,
            minDurationS: TrackingConfig.roadLiveMinDurationS, minHairpins: TrackingConfig.roadLiveMinHairpins)
        ? open.startTs
        : null;
  }

  /// Diagnostics: full finalize passes so far (≈ state transitions + finish).
  int get fullRecomputes => _fullRecomputes;

  /// Diagnostics: finalize passes of any kind. Tests use it to compare the
  /// spliced tail against a full pass over *exactly* the points the last pass
  /// saw — comparing on any other tick only measures the refresh cadence.
  int get recomputes => _recomputes;

  /// A run that will not survive [TrackingConfig.runMinDurationS] once its
  /// boundaries are final must not put a top speed on the screen.
  ///
  /// The open interval always reaches to the current tick, so it carries the
  /// standstill at its end until the segmenter has counted
  /// [TrackingConfig.runStopAbsorbS] of it and backdates the boundary — and a GPS
  /// dropout stretches it further still, on time with no fixes at all. Measured on
  /// [SkiProfiles.funicularTunnel]: a 27 s ride out of the tunnel into the valley
  /// station looked like a 60 s RUN and showed 32 km/h for 17 s, on a day whose
  /// finished numbers are 0 runs and 0,0 km/h.
  ///
  /// So the two spans the final pass will actually see are measured here — the
  /// interval minus its trailing standstill, and the part of it that fixes cover —
  /// and while either is short of the floor the peaks wait. A genuine run clears
  /// the floor by minutes and is never held.
  void _updateShortRunHold(int ts) {
    final open = _segmenter.open;
    if (open == null || open.kind != SegmentKind.run) {
      _shortRunHoldFrom = null;
      return;
    }
    final lastMoving = _lastMovingTs ?? open.startTs;
    final lastFix = _lastAcceptedTs ?? open.startTs;
    final moving = lastMoving - open.startTs;
    final covered = lastFix - open.startTs;
    final effective = moving < covered ? moving : covered;
    _shortRunHoldFrom = effective < TrackingConfig.runMinDurationS * 1000 ? open.startTs : null;
  }

  void _refreshLive(int nowMs, {required bool hasFix}) {
    Segment? lastRun;
    for (final s in _segments.reversed) {
      if (s.kind == SegmentKind.run) {
        lastRun = s;
        break;
      }
    }
    final stats = _stats.copyWith(
      elapsedMs: points.isEmpty ? 0 : nowMs - points.first.ts,
      maxSpeedMs: _liveMaxSpeed(),
    );
    _live = LiveState(
      stats: stats,
      speedMs: hasFix || (_lastAcceptedTs != null && nowMs - _lastAcceptedTs! <= 3000) ? _speed.displaySpeed : 0,
      altM: _alt.value,
      state: _segmenter.motionState,
      gps: _gps.quality(nowMs),
      lastRun: lastRun,
      batteryEtaTs: _batteryEtaTs,
      batteryPct: _batteryPct,
      heartRateBpm: points.isEmpty ? null : points.last.heartRateBpm ?? _live.heartRateBpm,
      lastFixTs: _lastAcceptedTs,
    );
  }

  /// Final segments + stats (forces a full recompute).
  DayComputation finish() {
    _recompute(full: true);
    return DayComputation(segments: _segments, stats: _stats, points: List.unmodifiable(points));
  }

  /// Offline replay of stored points through the same code path.
  static DayComputation computeDay(String dayId, List<TrackPoint> stored) {
    final e = TrackingEngine(dayId: dayId);
    final sorted = [...stored]..sort((a, b) => a.ts.compareTo(b.ts));
    for (final p in sorted) {
      if (p.hasPosition) {
        e.addFix(RawFix(
          ts: p.ts, lat: p.lat!, lon: p.lon!, hAccM: p.hAccM ?? 99, gpsAltM: p.gpsAltM, vAccM: p.vAccM,
          speedMs: p.speedMs, speedAccMs: p.speedAccMs, courseDeg: p.courseDeg,
        ));
      }
      if (p.pressureHpa != null) e.addPressure(PressureSample(ts: p.ts, hPa: p.pressureHpa!));
      if (p.heartRateBpm != null) e.addHeartRate(p.heartRateBpm!);
      e.tick(p.ts);
    }
    return e.finish();
  }

  int? get lastTickTs => _lastTickTs;
}
