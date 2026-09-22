import '../../core/core.dart';

enum GuardAction { none, remindIdle, autoEndIdle, autoEndVehicle, remindFourHours, warnBattery }

/// Pure decision logic for the safety guards (docs/PLAN.md §5). Stateful so
/// each reminder fires once per day.
class Guards {
  Guards({required this.dayStartMs});
  final int dayStartMs;
  bool _idleReminded = false, _fourHoursReminded = false, _batteryWarned = false;
  int? _vehicleSince;
  int? _lastRunEndMs;
  int? _stopSince;

  List<GuardAction> evaluate(LiveState live, int nowMs) {
    final out = <GuardAction>[];
    final run = live.lastRun;
    if (run != null) _lastRunEndMs = run.endTs;

    // vehicle: sustained vehicle flag → auto end after 5 min
    if (live.stats.vehicleFlag && live.state == MotionState.other) {
      _vehicleSince ??= nowMs;
      if (nowMs - _vehicleSince! >= TrackingConfig.vehicleAutoEndS * 1000) out.add(GuardAction.autoEndVehicle);
    } else {
      _vehicleSince = null;
    }

    // idle after the last run
    if (live.state == MotionState.stop || live.state == MotionState.unknown) {
      _stopSince ??= nowMs;
    } else {
      _stopSince = null;
    }
    final idleRef = _lastRunEndMs ?? dayStartMs;
    final idleMin = (nowMs - idleRef) ~/ 60000;
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
}
