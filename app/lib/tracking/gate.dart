import '../core/core.dart';

/// Result of validating one raw fix before it touches any estimator.
class GateResult {
  const GateResult({
    required this.accepted,
    this.reason = RejectReason.none,
    this.speedTrusted = false,
    this.maxCandidate = false,
    this.altAnchor = false,
  });
  final bool accepted;
  final RejectReason reason;
  /// Doppler speed usable (speed ≥ 0, speedAcc ≤ 1.5 m/s).
  final bool speedTrusted;
  /// Good enough to be a max-speed candidate (hAcc ≤ 20, speedAcc ≤ 1.0).
  final bool maxCandidate;
  /// Good enough to anchor the barometer (vAcc ≤ 15 m).
  final bool altAnchor;

  static const rejectedStale = GateResult(accepted: false, reason: RejectReason.stale);
}

/// Rejects impossible fixes (docs/PLAN.md §5, "Gate"). Stateful: remembers the
/// last accepted fix for implied-speed and acceleration checks.
class FixGate {
  FixGate({this.config = const TrackingConfig()});
  final TrackingConfig config;

  RawFix? _last;
  double? _lastTrustedSpeed;
  int? _lastTrustedTs;

  RawFix? get lastAccepted => _last;

  void reset() {
    _last = null;
    _lastTrustedSpeed = null;
    _lastTrustedTs = null;
  }

  GateResult evaluate(RawFix f, int nowMs) {
    if (f.isMocked) return const GateResult(accepted: false, reason: RejectReason.mocked);
    if (nowMs - f.ts > TrackingConfig.maxFixAgeS * 1000) return GateResult.rejectedStale;
    final last = _last;
    if (last != null && f.ts <= last.ts) return const GateResult(accepted: false, reason: RejectReason.nonMonotonic);
    if (f.hAccM > TrackingConfig.maxHorizontalAccuracyM) return const GateResult(accepted: false, reason: RejectReason.hAcc);
    final alt = f.gpsAltM;
    if (alt != null && (alt < TrackingConfig.minAltitudeM || alt > TrackingConfig.maxAltitudeM)) {
      return const GateResult(accepted: false, reason: RejectReason.altitudeRange);
    }
    final speedTrusted = f.speedMs != null && f.speedMs! >= 0 && (f.speedAccMs ?? 99) <= TrackingConfig.speedTrustedMaxAccMs;
    if (last != null) {
      final dt = (f.ts - last.ts) / 1000;
      if (dt > 0) {
        final d = haversineM(last.lat, last.lon, f.lat, f.lon);
        if (d / dt > TrackingConfig.maxImpliedSpeedMs) {
          return const GateResult(accepted: false, reason: RejectReason.impliedSpeed);
        }
      }
      if (speedTrusted && _lastTrustedSpeed != null && _lastTrustedTs != null) {
        final dts = (f.ts - _lastTrustedTs!) / 1000;
        if (dts > 0 && dts <= TrackingConfig.distanceMaxDtS) {
          final accel = (f.speedMs! - _lastTrustedSpeed!).abs() / dts;
          if (accel > TrackingConfig.maxAccelMs2) return const GateResult(accepted: false, reason: RejectReason.accel);
        }
      }
    }
    _last = f;
    if (speedTrusted) {
      _lastTrustedSpeed = f.speedMs;
      _lastTrustedTs = f.ts;
    }
    return GateResult(
      accepted: true,
      speedTrusted: speedTrusted,
      maxCandidate: speedTrusted && f.hAccM <= TrackingConfig.maxCandidateHAccM && (f.speedAccMs ?? 99) <= TrackingConfig.maxCandidateSpeedAccMs,
      altAnchor: f.vAccM != null && f.vAccM! <= TrackingConfig.altAnchorMaxVAccM,
    );
  }
}
