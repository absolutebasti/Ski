import 'enums.dart';

/// One engine tick (≈1 Hz). Raw values are stored as received; `fusedAltM`
/// and `state` are the only derived fields that get persisted.
class TrackPoint {
  const TrackPoint({
    required this.ts,
    this.lat,
    this.lon,
    this.hAccM,
    this.gpsAltM,
    this.vAccM,
    this.speedMs,
    this.speedAccMs,
    this.courseDeg,
    this.pressureHpa,
    this.fusedAltM,
    this.accepted = false,
    this.rejectReason = RejectReason.none,
    this.state = MotionState.unknown,
    this.heartRateBpm,
  });

  final int ts;
  final double? lat;
  final double? lon;
  final double? hAccM;
  final double? gpsAltM;
  final double? vAccM;
  final double? speedMs;
  final double? speedAccMs;
  final double? courseDeg;
  final double? pressureHpa;
  final double? fusedAltM;
  final bool accepted;
  final RejectReason rejectReason;
  final MotionState state;
  /// From the Apple Watch (WP-13); null on phone-only days.
  final int? heartRateBpm;

  bool get hasPosition => lat != null && lon != null;

  TrackPoint copyWith({
    double? fusedAltM,
    bool? accepted,
    RejectReason? rejectReason,
    MotionState? state,
    int? heartRateBpm,
  }) =>
      TrackPoint(
        ts: ts, lat: lat, lon: lon, hAccM: hAccM, gpsAltM: gpsAltM, vAccM: vAccM,
        speedMs: speedMs, speedAccMs: speedAccMs, courseDeg: courseDeg, pressureHpa: pressureHpa,
        fusedAltM: fusedAltM ?? this.fusedAltM,
        accepted: accepted ?? this.accepted,
        rejectReason: rejectReason ?? this.rejectReason,
        state: state ?? this.state,
        heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      );

  Map<String, Object?> toJson() => {
        'ts': ts, 'lat': lat, 'lon': lon, 'hAccM': hAccM, 'gpsAltM': gpsAltM, 'vAccM': vAccM,
        'speedMs': speedMs, 'speedAccMs': speedAccMs, 'courseDeg': courseDeg,
        'pressureHpa': pressureHpa, 'fusedAltM': fusedAltM, 'accepted': accepted,
        'rejectReason': rejectReason.name, 'state': state.name, 'heartRateBpm': heartRateBpm,
      };

  factory TrackPoint.fromJson(Map<String, Object?> j) => TrackPoint(
        ts: (j['ts'] as num).toInt(),
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        hAccM: (j['hAccM'] as num?)?.toDouble(),
        gpsAltM: (j['gpsAltM'] as num?)?.toDouble(),
        vAccM: (j['vAccM'] as num?)?.toDouble(),
        speedMs: (j['speedMs'] as num?)?.toDouble(),
        speedAccMs: (j['speedAccMs'] as num?)?.toDouble(),
        courseDeg: (j['courseDeg'] as num?)?.toDouble(),
        pressureHpa: (j['pressureHpa'] as num?)?.toDouble(),
        fusedAltM: (j['fusedAltM'] as num?)?.toDouble(),
        accepted: j['accepted'] == true,
        rejectReason: RejectReason.values.firstWhere((e) => e.name == j['rejectReason'], orElse: () => RejectReason.none),
        state: MotionState.values.firstWhere((e) => e.name == j['state'], orElse: () => MotionState.unknown),
        heartRateBpm: (j['heartRateBpm'] as num?)?.toInt(),
      );
}
