import 'package:drift/native.dart';
import 'package:schwung/core/core.dart';
import 'package:schwung/data/db/database.dart';
import 'package:schwung/data/db/days_repository.dart';
import 'package:schwung/tracking/synthetic.dart';
import 'package:schwung/tracking/tracking.dart';

/// 2026-01-15 09:00 — inside season 2025/26.
final int tsThisSeason = DateTime(2026, 1, 15, 9).millisecondsSinceEpoch;

/// 2025-03-02 09:00 — inside season 2024/25.
final int tsLastSeason = DateTime(2025, 3, 2, 9).millisecondsSinceEpoch;

DaySummary summary({
  required String id,
  required int startedAt,
  String? resortName = 'Kitzbühel',
  int runCount = 7,
  double dropM = 1804,
  double maxSpeedMs = 17,
  String? mapThumbPath,
  bool isTopSpeedPb = false,
  bool isBiggestDayPb = false,
}) =>
    DaySummary(
      id: id,
      startedAt: startedAt,
      endedAt: startedAt + 5 * 3600 * 1000,
      resortName: resortName,
      mapThumbPath: mapThumbPath,
      isTopSpeedPb: isTopSpeedPb,
      isBiggestDayPb: isBiggestDayPb,
      stats: DayStats(runCount: runCount, dropM: dropM, maxSpeedMs: maxSpeedMs),
    );

/// A seeded synthetic day pushed through the engine at 1 Hz, wrapped exactly
/// like `DaysRepository.dayDetail` would return it.
DayDetail syntheticDayDetail({
  String id = '0192abcd-0000-7000-8000-0000000000aa',
  int seed = 7,
  String? resortName = 'Kitzbühel',
  String? weatherJson,
  String? mapThumbPath,
}) {
  final day = SyntheticDayGenerator(seed: seed).generate();
  final engine = TrackingEngine(dayId: id);
  var fi = 0, pi = 0;
  final start = day.pressures.first.ts, end = day.pressures.last.ts;
  for (var ts = start; ts <= end; ts += 1000) {
    while (fi < day.fixes.length && day.fixes[fi].ts <= ts) {
      engine.addFix(day.fixes[fi++]);
    }
    while (pi < day.pressures.length && day.pressures[pi].ts <= ts) {
      engine.addPressure(day.pressures[pi++]);
    }
    engine.tick(ts);
  }
  final c = engine.finish();
  return DayDetail(
    day: DayRecord(
      id: id,
      startedAt: c.points.first.ts,
      endedAt: c.points.last.ts,
      status: DayStatus.finished,
      resortId: resortName == null ? null : 'kitzbuehel',
      resortName: resortName,
      lastFixAt: c.points.last.ts,
      weatherJson: weatherJson,
      mapThumbPath: mapThumbPath,
      stats: c.stats,
    ),
    segments: c.segments,
    points: c.points.where((p) => p.accepted).toList(),
  );
}

/// Records `softDeleteDay` instead of touching a real database.
class RecordingRepository extends DaysRepository {
  RecordingRepository() : super(AppDatabase(NativeDatabase.memory()));
  final deleted = <String>[];

  @override
  Future<void> softDeleteDay(String id) async => deleted.add(id);
}
