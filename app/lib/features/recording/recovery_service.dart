import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../data/db/providers.dart';
import 'recording_clock.dart';

/// An active day that was interrupted long enough to need a decision from the user.
class RecoveryInfo {
  const RecoveryInfo({required this.dayId, required this.startedAt, required this.lastFixAt, required this.runCount, required this.dropM, this.resortName});
  final String dayId;
  final int startedAt;
  final int? lastFixAt;
  final int runCount;
  final double dropM;
  final String? resortName;
}

/// Non-null when an active day exists whose last fix is older than 30 min and
/// no recording is running. Screens show the recovery card; the controller's
/// endRecoveredDay / resumeDay / discardRecoveredDay resolve it.
final recoveryProvider = FutureProvider<RecoveryInfo?>((ref) async {
  ref.watch(recoveryRefreshProvider);
  final repo = ref.watch(daysRepositoryProvider);
  final now = ref.watch(recordingClockProvider).now();
  final d = await repo.activeDay();
  if (d == null) return null;
  final last = d.lastFixAt ?? d.startedAt;
  if (now - last < TrackingConfig.silentResumeMaxMin * 60000) return null;
  return RecoveryInfo(dayId: d.id, startedAt: d.startedAt, lastFixAt: d.lastFixAt, runCount: d.stats.runCount, dropM: d.stats.dropM, resortName: d.resortName);
});

/// Bumped by the controller after any change to the active day.
class RecoveryRefresh extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final recoveryRefreshProvider = NotifierProvider<RecoveryRefresh, int>(RecoveryRefresh.new);
