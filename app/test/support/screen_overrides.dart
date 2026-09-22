import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:schwung/core/core.dart';
import 'package:schwung/core/settings.dart';
import 'package:schwung/data/db/providers.dart';
import 'package:schwung/data/resorts/resort_repository.dart';
import 'package:schwung/features/recording/recovery_service.dart';
import 'package:schwung/features/settings/settings_providers.dart';
import 'package:schwung/platform/permission_service.dart';
import 'package:schwung/platform/providers.dart';

import 'fakes.dart';

/// Everything RootShell / HeuteScreen / TageScreen touch, faked in memory so a
/// widget test never opens a database, a plugin or a timer that outlives it.
List<Override> screenOverrides({
  List<DaySummary> days = const [],
  List<SeasonTotals> seasons = const [],
  PersonalBests bests = const PersonalBests(),
  Settings settings = const Settings(onboardingDone: true),
  PermissionService? permissions,
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
      resortRepositoryProvider.overrideWith((ref) async => ResortRepository(const [])),
      permissionServiceProvider.overrideWithValue(permissions ?? FakePermissionService()),
      barometerSourceProvider.overrideWithValue(FakeBarometerSource(const [])),
      locationSourceProvider.overrideWithValue(ManualLocationSource()),
      batterySourceProvider.overrideWithValue(FakeBatterySource()),
      heartRateSourceProvider.overrideWithValue(NoHeartRate()),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      watchdogChannelProvider.overrideWithValue(FakeWatchdog()),
    ];
