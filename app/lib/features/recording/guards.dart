import '../../core/core.dart';

enum GuardAction { none, remindIdle, autoEndIdle, autoEndVehicle, remindFourHours, warnBattery, autoEndMidnight, autoEndMaxDuration, autoEndNoAccess }

/// Minutes without location access (service off / permission revoked) after
/// which the day is closed. Local until TrackingConfig.noAccessAutoEndMin exists.

/// Pure decision logic for the safety guards (docs/PLAN.md §5). Stateful so
/// each reminder fires once per day.
class Guards {
  /// [sessionStartMs]: when this recording session began — later than
  /// [dayStartMs] after a restart merge or a resume. Idle time never counts
  /// from before it, so a day reopened after a long lunch is not closed again
  /// on its first tick.
  Guards({required this.dayStartMs, int? sessionStartMs}) : _activeMs = sessionStartMs ?? dayStartMs;
  final int dayStartMs;
  bool _idleReminded = false, _fourHoursReminded = false, _batteryWarned = false;
  int? _vehicleSince;
  int? _stopSince;
  /// Last moment the rider was skiing or riding a lift (or the session start).
  int _activeMs;

  /// [accessLostSinceMs]: wall clock when location access was lost, null while ok.
  List<GuardAction> evaluate(LiveState live, int nowMs, {int? accessLostSinceMs}) {
    final out = <GuardAction>[];
    final run = live.lastRun;
    if (run != null && run.endTs > _activeMs) _activeMs = run.endTs;
    // Lifts count as activity too: a beginner whose short runs never pass the
    // run thresholds still rides lifts all day.
    if (live.state == MotionState.run || live.state == MotionState.lift) _activeMs = nowMs;

    // no access: nothing is being recorded; close the day after 30 min.
    if (accessLostSinceMs != null && nowMs - accessLostSinceMs >= TrackingConfig.noAccessAutoEndMin * 60000) {
      out.add(GuardAction.autoEndNoAccess);
    }

    // day boundary: a recording never spans two calendar days (local 03:00
    // after a start on the previous day) and never runs longer than maxDayH.
    if (nowMs - dayStartMs >= TrackingConfig.maxDayH * 3600000) {
      out.add(GuardAction.autoEndMaxDuration);
    } else if (crossedRollover(dayStartMs, nowMs)) {
      out.add(GuardAction.autoEndMidnight);
    }

    // vehicle: sustained vehicle flag → auto end after 5 min
    if (live.stats.vehicleFlag && live.state == MotionState.other) {
      _vehicleSince ??= nowMs;
      if (nowMs - _vehicleSince! >= TrackingConfig.vehicleAutoEndS * 1000) out.add(GuardAction.autoEndVehicle);
    } else {
      _vehicleSince = null;
    }

    // idle: stopped, and no run or lift since idleReminderMin / idleAutoEndMin
    if (live.state == MotionState.stop || live.state == MotionState.unknown) {
      _stopSince ??= nowMs;
    } else {
      _stopSince = null;
    }
    final idleMin = (nowMs - _activeMs) ~/ 60000;
    if (_stopSince != null && idleMin >= TrackingConfig.idleAutoEndMin) {
      out.add(GuardAction.autoEndIdle);
    } else if (_stopSince != null && idleMin >= TrackingConfig.idleReminderMin && !_idleReminded) {
      _idleReminded = true;
      out.add(GuardAction.remindIdle);
    }

    if (!_fourHoursReminded && nowMs - dayStartMs >= TrackingConfig.dayReminderH * 3600000) {
      _fourHoursReminded = true;
      out.add(GuardAction.remindFourHours);
    }
    final pct = live.batteryPct;
    if (!_batteryWarned && pct != null && pct <= TrackingConfig.batteryWarnPct) {
      _batteryWarned = true;
      out.add(GuardAction.warnBattery);
    }
    return out.isEmpty ? const [GuardAction.none] : out;
  }

  /// Trailing idle time to trim on auto-end.
  int? get stopSince => _stopSince;

  /// True when a day that started at [startMs] may no longer record at
  /// [nowMs]: past the 03:00 rollover or longer than maxDayH. Such a day is
  /// finished from its stored points, never resumed or appended to.
  static bool dayExpired(int startMs, int nowMs) =>
      nowMs - startMs >= TrackingConfig.maxDayH * 3600000 || crossedRollover(startMs, nowMs);

  /// True once local time passed [TrackingConfig.dayRolloverHour] on a later
  /// calendar day than the start (device time zone).
  static bool crossedRollover(int startMs, int nowMs) {
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    final rollover = DateTime(start.year, start.month, start.day + 1, TrackingConfig.dayRolloverHour);
    return !now.isBefore(rollover);
  }
}
