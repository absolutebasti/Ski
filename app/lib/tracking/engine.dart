import '../core/core.dart';
import 'altitude.dart';
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
  final MaxSpeedTracker _dayMax = MaxSpeedTracker();
  VerticalAccumulator? _vertical;

  final List<TrackPoint> points = [];
  List<Segment> _segments = const [];
  DayStats _stats = DayStats.empty;
  LiveState _live = LiveState.empty;

  RawFix? _pendingFix;
  PressureSample? _pendingPressure;
  int? _pendingHr;
  int? _lastAcceptedTs;
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
    double rawSpeed = 0;
    GateResult? g;
    if (fix != null) {
      g = _gate.evaluate(fix, nowMs);
      accepted = g.accepted;
      reason = g.reason;
      if (accepted) {
        _lastAcceptedTs = fix.ts;
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
    final before = _segmenter.intervals.length;
    _segmenter.tick(SegTick(ts: ts, vH: _speed.displaySpeed, h: fused, hasFix: accepted, gapMs: accepted ? 0 : gapMs));
    final intervalsChanged = _segmenter.intervals.length != before;

    if (accepted && g != null && g.maxCandidate && _segmenter.state == SegmentKind.run) {
      _dayMax.offer(rawSpeed, ts);
    }

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
    _lastTickTs = ts;

    _ticksSinceRecompute++;
    var newSegs = const <Segment>[];
    var changed = false;
    if (intervalsChanged || _ticksSinceRecompute >= 5) {
      _recompute();
      _ticksSinceRecompute = 0;
      if (_segments.length > _finalizedCount || intervalsChanged) {
        changed = true;
        newSegs = _segments.skip(_finalizedCount).where((s) => s.endTs <= (_segmenter.open?.startTs ?? s.endTs)).toList();
        _finalizedCount = _segments.length;
      }
    }
    _refreshLive(nowMs, hasFix: accepted);
    return EngineTick(point: point, live: _live, newSegments: newSegs, segmentsChanged: changed);
  }

  void _recompute() {
    _segments = finalizeSegments(_segmenter.allIntervals, points, dayId: dayId);
    _stats = computeDayStats(_segments, points, hasBarometer: _alt.hasBarometer);
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
      maxSpeedMs: _dayMax.max > _stats.maxSpeedMs ? _dayMax.max : _stats.maxSpeedMs,
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

  /// Final segments + stats (forces a recompute).
  DayComputation finish() {
    _recompute();
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
