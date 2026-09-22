import '../core/core.dart';

/// Turning-point hysteresis on fused altitude. Diagnostic totals; the UI uses
/// per-run drops from the segmenter.
class VerticalAccumulator {
  VerticalAccumulator({required bool hasBarometer})
      : threshold = hasBarometer ? TrackingConfig.verticalHysteresisBaroM : TrackingConfig.verticalHysteresisGpsM;

  final double threshold;
  double descentM = 0;
  double ascentM = 0;
  double? _extreme;
  int _dir = 0; // +1 rising, -1 falling, 0 unknown
  double? _committed;

  void update(double h) {
    final e = _extreme;
    if (e == null) {
      _extreme = h;
      _committed = h;
      return;
    }
    if (_dir >= 0 && h > e) {
      _extreme = h;
    } else if (_dir <= 0 && h < e) {
      _extreme = h;
    } else if (_dir >= 0 && e - h >= threshold) {
      // was rising, now fell by threshold: commit the rise
      if (_dir == 1) ascentM += e - (_committed ?? e);
      _committed = e;
      _dir = -1;
      _extreme = h;
    } else if (_dir <= 0 && h - e >= threshold) {
      if (_dir == -1) descentM += (_committed ?? e) - e;
      _committed = e;
      _dir = 1;
      _extreme = h;
    }
    if (_dir == 0) {
      if (h - (_committed ?? h) >= threshold) _dir = 1;
      if ((_committed ?? h) - h >= threshold) _dir = -1;
    }
  }
}
