import 'dart:math' as math;

import '../../core/core.dart';

/// One rendered sample: seconds since the first point, altitude in metres.
class ProfileSample {
  const ProfileSample(this.ts, this.elapsedS, this.altM);
  final int ts;
  final double elapsedS;
  final double altM;
}

/// Shaded x-range in elapsed seconds.
class ProfileRange {
  const ProfileRange(this.fromS, this.toS);
  final double fromS;
  final double toS;
}

/// Pure data preparation for [AltitudeProfile]: filtering, downsampling and
/// axis bounds. Kept free of Flutter so it can be unit-tested directly.
class ProfileSeries {
  ProfileSeries._({
    required this.t0,
    required this.samples,
    required this.lifts,
    required this.signalLoss,
    required this.minAltM,
    required this.maxAltM,
    required this.durationS,
  });

  /// ts of the first usable point; x = (ts - t0) / 1000.
  final int t0;
  final List<ProfileSample> samples;
  final List<ProfileRange> lifts;
  final List<ProfileRange> signalLoss;
  final double minAltM;
  final double maxAltM;
  final double durationS;

  bool get isEmpty => samples.length < 2;

  /// Largest number of samples handed to the chart.
  static const int maxSamples = 1500;

  static ProfileSeries build(List<TrackPoint> points, List<Segment> segments, {int maxSamples = maxSamples}) {
    final usable = points.where((p) => p.accepted && p.fusedAltM != null && p.fusedAltM!.isFinite).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    if (usable.isEmpty) {
      return ProfileSeries._(t0: 0, samples: const [], lifts: const [], signalLoss: const [], minAltM: 0, maxAltM: 0, durationS: 0);
    }
    final t0 = usable.first.ts;
    final picked = downsample(usable, maxSamples);
    final samples = [for (final p in picked) ProfileSample(p.ts, (p.ts - t0) / 1000, p.fusedAltM!)];
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final s in samples) {
      lo = math.min(lo, s.altM);
      hi = math.max(hi, s.altM);
    }
    final durationS = (usable.last.ts - t0) / 1000;
    ProfileRange clip(Segment s) => ProfileRange(
          ((s.startTs - t0) / 1000).clamp(0, durationS).toDouble(),
          ((s.endTs - t0) / 1000).clamp(0, durationS).toDouble(),
        );
    final sorted = [...segments]..sort((a, b) => a.idx.compareTo(b.idx));
    return ProfileSeries._(
      t0: t0,
      samples: samples,
      lifts: [for (final s in sorted) if (s.kind == SegmentKind.lift && s.endTs > s.startTs) clip(s)],
      signalLoss: [for (final s in sorted) if (s.kind == SegmentKind.signalLoss && s.endTs > s.startTs) clip(s)],
      minAltM: lo,
      maxAltM: hi,
      durationS: durationS,
    );
  }

  /// Min/max bucket downsampling: keeps peaks and valleys, ≤ [max] points.
  static List<TrackPoint> downsample(List<TrackPoint> pts, int max) {
    if (pts.length <= max) return pts;
    final buckets = math.max(1, max ~/ 2);
    final out = <TrackPoint>[];
    final step = pts.length / buckets;
    for (var b = 0; b < buckets; b++) {
      final from = (b * step).floor();
      final to = b == buckets - 1 ? pts.length : math.min(pts.length, ((b + 1) * step).floor());
      if (to <= from) continue;
      var lo = pts[from], hi = pts[from];
      for (var i = from + 1; i < to; i++) {
        final p = pts[i];
        if (p.fusedAltM! < lo.fusedAltM!) lo = p;
        if (p.fusedAltM! > hi.fusedAltM!) hi = p;
      }
      if (lo.ts <= hi.ts) {
        out.add(lo);
        if (hi != lo) out.add(hi);
      } else {
        out.add(hi);
        out.add(lo);
      }
    }
    if (out.first != pts.first) out.insert(0, pts.first);
    if (out.last != pts.last) out.add(pts.last);
    return out;
  }

  /// Rounded y-axis bounds and tick interval (metres).
  ({double min, double max, double interval}) get altitudeAxis {
    final span = math.max(50.0, maxAltM - minAltM);
    final interval = span <= 300 ? 100.0 : span <= 800 ? 200.0 : span <= 2000 ? 500.0 : 1000.0;
    final min = (minAltM / interval).floor() * interval;
    var max = (maxAltM / interval).ceil() * interval;
    if (max - min < interval) max = min + interval;
    return (min: min, max: max, interval: interval);
  }

  /// Tick interval for the time axis (seconds) yielding roughly 4–6 labels.
  double get timeInterval {
    const candidates = [60.0, 300.0, 600.0, 900.0, 1800.0, 3600.0, 7200.0];
    final target = math.max(1.0, durationS) / 5;
    for (final c in candidates) {
      if (c >= target) return c;
    }
    return candidates.last;
  }

  /// Sample nearest to elapsed second [x].
  ProfileSample? nearest(double x) {
    if (samples.isEmpty) return null;
    var lo = 0, hi = samples.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (samples[mid].elapsedS < x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0 && (x - samples[lo - 1].elapsedS).abs() < (samples[lo].elapsedS - x).abs()) return samples[lo - 1];
    return samples[lo];
  }
}
