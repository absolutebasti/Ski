import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:dropline/core/core.dart';
import 'package:dropline/core/settings.dart';
import 'package:dropline/data/db/providers.dart';
import 'package:dropline/features/recording/live_state_provider.dart';
import 'package:dropline/features/recording/recording_controller.dart';
import 'package:dropline/features/recording/recovery_service.dart';
import 'package:dropline/features/settings/settings_providers.dart';
import 'package:dropline/platform/permission_service.dart';

/// 2026-01-15 09:00 — inside season 2025/26.
final int tsDay = DateTime(2026, 1, 15, 9).millisecondsSinceEpoch;

DaySummary daySummary({
  String id = 'day-1',
  String? resortName = 'Kitzbühel',
  int runCount = 7,
  double dropM = 1804,
  double maxSpeedMs = 17,
}) =>
    DaySummary(
      id: id,
      startedAt: tsDay,
      endedAt: tsDay + 5 * 3600 * 1000,
      resortName: resortName,
      stats: DayStats(runCount: runCount, dropM: dropM, maxSpeedMs: maxSpeedMs),
    );

/// Records the calls the Heute screen makes and never touches sensors or the DB.
class FakeRecordingController extends RecordingController {
  FakeRecordingController({
    this.initial = RecordingState.idle,
    this.startError,
    this.endResult = 'day-1',
    this.recoveredResult = 'rec-1',
  });

  final RecordingState initial;
  final RecordingErrorKind? startError;
  final String? endResult;
  final String? recoveredResult;

  int startCalls = 0;
  int endCalls = 0;
  final List<String> recoveredEnds = [];
  final List<String> resumed = [];
  final List<String> discarded = [];
  final List<String> recomputed = [];

  @override
  RecordingState build() => initial;

  @override
  Future<void> startDay() async {
    startCalls++;
    final e = startError;
    if (e != null) throw RecordingError(e);
    state = RecordingState(status: RecordingStatus.recording, dayId: 'day-live', startedAt: tsDay);
  }

  @override
  Future<String?> endDay({int? trimTrailingIdleFrom}) async {
    endCalls++;
    state = RecordingState.idle;
    return endResult;
  }

  @override
  Future<String?> endRecoveredDay(String dayId) async {
    recoveredEnds.add(dayId);
    return recoveredResult;
  }

  @override
  Future<bool> resumeDay(String dayId) async {
    resumed.add(dayId);
    return true;
  }

  @override
  Future<void> discardRecoveredDay(String dayId) async => discarded.add(dayId);

  @override
  Future<void> recomputeDay(String dayId) async => recomputed.add(dayId);
}

/// A LiveState that never ticks.
class SeededLive extends LiveStateNotifier {
  SeededLive(this.value);
  final LiveState value;
  @override
  LiveState build() => value;
}

/// SettingsNotifier without shared_preferences, seeded with [initial].
class TestSettings extends SettingsNotifier {
  TestSettings([this.initial = const Settings()]) : super(null);
  final Settings initial;
  @override
  Settings build() => initial;
}

List<Override> todayOverrides({
  required FakeRecordingController controller,
  List<DaySummary> days = const [],
  List<SeasonTotals> totals = const [],
  LiveState live = LiveState.empty,
  RecoveryInfo? recovery,
  Settings settings = const Settings(),
  PersonalBests? bests,
}) =>
    [
      recordingControllerProvider.overrideWith(() => controller),
      liveStateNotifierProvider.overrideWith(() => SeededLive(live)),
      daysListProvider.overrideWith((ref) => Stream.value(days)),
      seasonTotalsProvider.overrideWith((ref) => Stream.value(totals)),
      recoveryProvider.overrideWith((ref) async => recovery),
      personalBestsProvider.overrideWith((ref) => Stream.value(bests ?? const PersonalBests())),
      preciseLocationProvider.overrideWith((ref) async => true),
      settingsProvider.overrideWith(() => TestSettings(settings)),
      locationStatusProvider.overrideWith((ref) async => LocationPermissionState.always),
      appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
    ];

/// A local navigator so `AppNav.openSummary` has a route generator to talk to.
Widget hostWithRoutes(Widget child, List<String> pushed) => Navigator(
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        if (name != '/') pushed.add(name);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => name == '/' ? child : const Scaffold(body: Text('pushed')),
        );
      },
    );
