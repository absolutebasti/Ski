import 'dart:math' as math;

import '../core/core.dart';

/// Pre-filters raw pressure: median-of-3 and a 3 hPa/s rate limit.
class BaroFilter {
  final List<double> _win = [];
  PressureSample? _last;

  /// Returns the filtered sample or null if the reading is an artefact.
  PressureSample? filter(PressureSample s) {
    final last = _last;
    if (last != null) {
      final dt = (s.ts - last.ts) / 1000;
      if (dt > 0 && (s.hPa - last.hPa).abs() / dt > TrackingConfig.baroMaxRateHpaPerS) return null;
    }
    _last = s;
    _win.add(s.hPa);
    if (_win.length > 3) _win.removeAt(0);
    final sorted = [..._win]..sort();
    return PressureSample(ts: s.ts, hPa: sorted[sorted.length ~/ 2]);
  }

  void reset() {
    _win.clear();
    _last = null;
  }
}

double hypsometricAltitude(double hPa) =>
    TrackingConfig.hypsometricScaleM * (1 - math.pow(hPa / TrackingConfig.seaLevelHpa, TrackingConfig.hypsometricExponent));

/// h_fused = a + k · h_baro, anchored to GPS. GPS-only EMA when no barometer.
class AltitudeFuser {
  final List<double> _anchorInit = [];
  double? _a;
  double _k = 1.0;
  double? _kWindowBaroStart;
  double? _kWindowGpsStart;
  double _kWindowWeightStart = 0;
  double? _lastBaroH;
  int? _lastBaroTs;
  double? _gpsEma;
  bool _hasBaro = false;
  double? _fused;

  bool get hasBarometer => _hasBaro;
  bool get isAnchored => _a != null;
  double get scaleFactor => _k;
  double? get value => _fused;

  void reset() {
    _anchorInit.clear();
    _a = null;
    _k = 1.0;
    _kWindowBaroStart = null;
    _kWindowGpsStart = null;
    _lastBaroH = null;
    _lastBaroTs = null;
    _gpsEma = null;
    _hasBaro = false;
    _fused = null;
  }

  /// Feed a filtered pressure sample; returns the fused altitude if anchored.
  double? addPressure(PressureSample s) {
    _hasBaro = true;
    _lastBaroH = hypsometricAltitude(s.hPa);
    _lastBaroTs = s.ts;
    return _recompute();
  }

  /// Feed an accepted GPS fix.
  double? addFix(RawFix f, {required bool altAnchor, required int nowMs}) {
    final alt = f.gpsAltM;
    if (alt != null && altAnchor) {
      _gpsEma = _gpsEma == null ? alt : _gpsEma! + TrackingConfig.gpsOnlyAltEmaAlpha * (alt - _gpsEma!);
      final baroFresh = _lastBaroTs != null && nowMs - _lastBaroTs! <= TrackingConfig.baroMaxAgeS * 1000;
      if (_hasBaro && baroFresh && _lastBaroH != null) {
        final offset = alt - _k * _lastBaroH!;
        if (_a == null) {
          _anchorInit.add(offset);
          if (_anchorInit.length >= TrackingConfig.anchorInitFixes) {
            final sorted = [..._anchorInit]..sort();
            _a = sorted[sorted.length ~/ 2];
            _kWindowBaroStart = _lastBaroH;
            _kWindowGpsStart = alt;
            _kWindowWeightStart = 1 / math.pow(math.max(f.vAccM ?? 1, 1), 2);
          }
        } else {
          _a = _a! + TrackingConfig.anchorEmaAlpha * (offset - _a!);
          _updateScale(alt, f.vAccM ?? 15);
        }
      }
    }
    return _recompute();
  }

  void _updateScale(double gpsAlt, double vAcc) {
    if (!TrackingConfig.baroScaleCorrectionEnabled) return;
    final b0 = _kWindowBaroStart, g0 = _kWindowGpsStart, b1 = _lastBaroH;
    if (b0 == null || g0 == null || b1 == null) return;
    final dBaro = b1 - b0;
    if (dBaro.abs() < TrackingConfig.kUpdateMinBaroChangeM) return;
    final w = 1 / math.pow(math.max(vAcc, 1), 2);
    // Weight the observation by the worse of the two end-point accuracies.
    final conf = math.min(w, _kWindowWeightStart) / math.max(w, _kWindowWeightStart);
    final kObs = (gpsAlt - g0) / dBaro;
    final blended = _k * TrackingConfig.kEmaOld + kObs * (1 - TrackingConfig.kEmaOld) * conf + _k * (1 - TrackingConfig.kEmaOld) * (1 - conf);
    _k = blended.clamp(TrackingConfig.kMin, TrackingConfig.kMax);
    _kWindowBaroStart = b1;
    _kWindowGpsStart = gpsAlt;
    _kWindowWeightStart = w;
  }

  double? _recompute() {
    if (_a != null && _lastBaroH != null) {
      _fused = _a! + _k * _lastBaroH!;
    } else if (_gpsEma != null) {
      _fused = _gpsEma;
    }
    return _fused;
  }
}
