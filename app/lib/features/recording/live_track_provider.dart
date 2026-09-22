import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';

/// Ring of the most recent accepted points for the live map sheet.
class LiveTrackNotifier extends Notifier<List<TrackPoint>> {
  @override
  List<TrackPoint> build() => const [];

  void add(TrackPoint p) {
    final next = [...state, p];
    if (next.length > TrackingConfig.liveRingPoints) next.removeRange(0, next.length - TrackingConfig.liveRingPoints);
    state = next;
  }

  void seed(Iterable<TrackPoint> points) {
    final list = points.where((p) => p.accepted).toList();
    state = list.length > TrackingConfig.liveRingPoints ? list.sublist(list.length - TrackingConfig.liveRingPoints) : list;
  }

  void clear() => state = const [];
}

final liveTrackProvider = NotifierProvider<LiveTrackNotifier, List<TrackPoint>>(LiveTrackNotifier.new);
