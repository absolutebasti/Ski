import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/data/resorts/resort_repository.dart';
import 'package:slopetrack/features/recording/recovery_service.dart';
import 'package:slopetrack/features/settings/settings_providers.dart';
import 'package:slopetrack/platform/permission_service.dart';
import 'package:slopetrack/platform/providers.dart';

import 'fakes.dart';

/// Everything RootShell / HeuteScreen / TageScreen touch, faked in memory so a
/// widget test never opens a database, a plugin or a timer that outlives it.
List<Override> screenOverrides({
  List<DaySummary> days = const [],
  List<SeasonTotals> seasons = const [],
  PersonalBests bests = const PersonalBests(),
  Settings settings = const Settings(onboardingDone: true),
  PermissionService? permissions,
  List<Resort> resorts = const [],
}) =>
    [
      locationStatusProvider.overrideWith((ref) async => LocationPermissionState.always),
      preciseLocationProvider.overrideWith((ref) async => true),
      barometerAvailableProvider.overrideWith((ref) async => true),
      appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
      settingsProvider.overrideWith(() => SettingsNotifier(null, initial: settings)),
      daysListProvider.overrideWith((ref) => Stream.value(days)),
      seasonTotalsProvider.overrideWith((ref) => Stream.value(seasons)),
      personalBestsProvider.overrideWith((ref) => Stream.value(bests)),
      recoveryProvider.overrideWith((ref) async => null),
      resortRepositoryProvider.overrideWith((ref) async => ResortRepository(resorts)),
      permissionServiceProvider.overrideWithValue(permissions ?? FakePermissionService()),
      barometerSourceProvider.overrideWithValue(FakeBarometerSource(const [])),
      locationSourceProvider.overrideWithValue(ManualLocationSource()),
      batterySourceProvider.overrideWithValue(FakeBatterySource()),
      heartRateSourceProvider.overrideWithValue(NoHeartRate()),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      watchdogChannelProvider.overrideWithValue(FakeWatchdog()),
    ];
