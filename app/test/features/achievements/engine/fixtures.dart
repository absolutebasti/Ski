import 'package:slopetrack/core/core.dart';

/// Local noon of 2026-01-[d] (mid-season, no DST edge).
int at(int day, {int hour = 10, int month = 1, int year = 2026}) => DateTime(year, month, day, hour).millisecondsSinceEpoch;

int _seq = 0;

/// A finished day with plain, non-suspicious defaults.
DaySummary day({
  required int startedAt,
  double dropM = 1000,
  double skiKm = 10,
  int runs = 8,
  double maxKmh = 50,
  int skiMinutes = 60,
  String? resortId,
}) =>
    DaySummary(
      id: 'd${_seq++}',
      startedAt: startedAt,
      endedAt: startedAt + 6 * 3600 * 1000,
      resortId: resortId,
      resortName: resortId,
      stats: DayStats(
        dropM: dropM,
        skiDistanceM: skiKm * 1000,
        runCount: runs,
        maxSpeedMs: maxKmh / 3.6,
        skiMs: skiMinutes * 60 * 1000,
        elapsedMs: 6 * 3600 * 1000,
      ),
    );

/// [n] consecutive local calendar days starting at day-of-month [from].
List<DaySummary> streakDays(int n, {int from = 1, String? resortId}) =>
    [for (var i = 0; i < n; i++) day(startedAt: at(from + i), resortId: resortId)];
