import 'dart:math' as math;

import 'package:dropline/core/core.dart';

/// 2026-01-15 09:00 — inside season 2025/26.
final int tsDay = DateTime(2026, 1, 15, 9).millisecondsSinceEpoch;

const _stats = DayStats(
  elapsedMs: 5 * 3600 * 1000,
  skiMs: 3600 * 1000,
  liftMs: 2 * 3600 * 1000,
  pauseMs: 1800 * 1000,
  runCount: 7,
  liftCount: 7,
  dropM: 1804,
  ascentM: 1790,
  skiDistanceM: 24500,
  liftDistanceM: 21000,
  totalDistanceM: 45500,
  maxSpeedMs: 17,
  avgSkiSpeedMs: 9,
  maxAltM: 1950,
  minAltM: 800,
  longestRunSegmentId: 'seg-3',
);

Segment _run({required String id, required int number, required double dropM, required double maxSpeedMs}) => Segment(
      id: id,
      dayId: 'day-1',
      kind: SegmentKind.run,
      idx: number - 1,
      runNumber: number,
      startTs: tsDay + number * 600000,
      endTs: tsDay + number * 600000 + 420000,
      dropM: dropM,
      distanceM: 2100,
      maxSpeedMs: maxSpeedMs,
      avgSpeedMs: 9,
      avgGradientPct: 14,
    );

/// A one-hour synthetic track around Kitzbühel so the route block has
/// something to draw. Points inside the run segments become champagne strokes,
/// everything between them a dashed lift.
List<TrackPoint> trackPoints({int count = 60}) => [
      for (var i = 0; i < count; i++)
        TrackPoint(
          ts: tsDay + i * 60000,
          lat: 47.44 + math.sin(i / 7) * 0.004 + i * 0.00012,
          lon: 12.39 + math.cos(i / 5) * 0.005 + i * 0.00010,
          fusedAltM: 1900 - math.sin(i / 7) * 300,
          speedMs: 8,
          accepted: true,
        ),
    ];

/// A finished day — everything the Tagesbilanz renders. [points] is empty by
/// default so most tests exercise the "Ohne Track" fallback.
DayDetail summaryDetail({
  String id = 'day-1',
  String? resortName = 'Kitzbühel',
  DayStats stats = _stats,
  List<TrackPoint> points = const [],
}) =>
    DayDetail(
      day: DayRecord(
        id: id,
        startedAt: tsDay,
        endedAt: tsDay + 5 * 3600 * 1000,
        status: DayStatus.finished,
        resortId: resortName == null ? null : 'kitzbuehel',
        resortName: resortName,
        lastFixAt: tsDay + 5 * 3600 * 1000,
        stats: stats,
      ),
      segments: [
        _run(id: 'seg-1', number: 1, dropM: 210, maxSpeedMs: 14),
        _run(id: 'seg-3', number: 3, dropM: 312, maxSpeedMs: 17),
      ],
      points: points,
    );
