import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/recording/guards.dart';

/// Guards are pure: feed a LiveState and a clock, read the actions.
void main() {
  final skiing = const LiveState(state: MotionState.run, batteryPct: 80);
  final resting = const LiveState(state: MotionState.stop, batteryPct: 80);

  int at(int y, int m, int d, int h, [int min = 0]) => DateTime(y, m, d, h, min).millisecondsSinceEpoch;

  test('a day started at 12:00 auto-ends at 03:00 the next day', () {
    final start = at(2027, 1, 10, 12); // 15 h until the rollover, under maxDayH
    final g = Guards(dayStartMs: start);
    expect(g.evaluate(skiing, at(2027, 1, 10, 23, 30)), isNot(contains(GuardAction.autoEndMidnight)));
    expect(g.evaluate(skiing, at(2027, 1, 11, 2, 59)), isNot(contains(GuardAction.autoEndMidnight)));
    expect(g.evaluate(skiing, at(2027, 1, 11, 3)), contains(GuardAction.autoEndMidnight));
  });

  test('a day started at 09:00 is closed by the 16 h cap before the rollover', () {
    final g = Guards(dayStartMs: at(2027, 1, 10, 9));
    final actions = g.evaluate(skiing, at(2027, 1, 11, 1));
    expect(actions, contains(GuardAction.autoEndMaxDuration));
  });

  test('a late start (22:00) still ends at 03:00, not after 24 h', () {
    final start = at(2027, 1, 10, 22);
    final g = Guards(dayStartMs: start);
    expect(g.evaluate(skiing, at(2027, 1, 11, 2, 30)), isNot(contains(GuardAction.autoEndMidnight)));
    expect(g.evaluate(skiing, at(2027, 1, 11, 3, 1)), contains(GuardAction.autoEndMidnight));
  });

  test('a day longer than maxDayH auto-ends even before the rollover', () {
    final start = at(2027, 1, 10, 4); // 04:00 → 16 h later is 20:00 the same day
    final g = Guards(dayStartMs: start);
    expect(g.evaluate(skiing, at(2027, 1, 10, 19, 59)), isNot(contains(GuardAction.autoEndMaxDuration)));
    final actions = g.evaluate(skiing, at(2027, 1, 10, 20));
    expect(actions, contains(GuardAction.autoEndMaxDuration));
    expect(actions, isNot(contains(GuardAction.autoEndMidnight)), reason: 'one auto-end at a time');
  });

  test('the existing idle behaviour is unchanged: reminder, then auto-end', () {
    final start = at(2027, 1, 10, 9);
    final g = Guards(dayStartMs: start);
    // Idle counts from the day start when no run happened yet.
    final remind = g.evaluate(resting, start + TrackingConfig.idleReminderMin * 60000);
    expect(remind, contains(GuardAction.remindIdle));
    final again = g.evaluate(resting, start + (TrackingConfig.idleReminderMin + 1) * 60000);
    expect(again, isNot(contains(GuardAction.remindIdle)), reason: 'reminder fires once');
    final end = g.evaluate(resting, start + TrackingConfig.idleAutoEndMin * 60000);
    expect(end, contains(GuardAction.autoEndIdle));
    expect(g.stopSince, isNotNull);
  });

  test('vehicle flag sustained for five minutes ends the day', () {
    final start = at(2027, 1, 10, 9);
    final g = Guards(dayStartMs: start);
    const car = LiveState(state: MotionState.other, stats: DayStats.empty, batteryPct: 80);
    final carFlagged = LiveState(state: MotionState.other, stats: car.stats.copyWith(vehicleFlag: true), batteryPct: 80);
    expect(g.evaluate(carFlagged, start + 60000), isNot(contains(GuardAction.autoEndVehicle)));
    expect(g.evaluate(carFlagged, start + 60000 + TrackingConfig.vehicleAutoEndS * 1000), contains(GuardAction.autoEndVehicle));
  });

  test('battery warning fires once at the threshold', () {
    final start = at(2027, 1, 10, 9);
    final g = Guards(dayStartMs: start);
    final low = LiveState(state: MotionState.run, batteryPct: TrackingConfig.batteryWarnPct);
    expect(g.evaluate(low, start + 1000), contains(GuardAction.warnBattery));
    expect(g.evaluate(low, start + 2000), isNot(contains(GuardAction.warnBattery)));
  });
}
