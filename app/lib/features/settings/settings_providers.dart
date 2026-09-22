import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../platform/permission_service.dart';
import '../../platform/providers.dart';

/// Current location permission, re-read whenever [settingsRefreshProvider] bumps.
final locationStatusProvider = FutureProvider<LocationPermissionState>((ref) async {
  ref.watch(settingsRefreshProvider);
  return ref.watch(permissionServiceProvider).status();
});

/// Whether iOS grants us full accuracy (diagnostics row).
final preciseLocationProvider = FutureProvider<bool>((ref) async {
  ref.watch(settingsRefreshProvider);
  return ref.watch(permissionServiceProvider).hasPreciseLocation();
});

/// Whether the device has a usable barometer (diagnostics row).
final barometerAvailableProvider = FutureProvider<bool>((ref) => ref.watch(barometerSourceProvider).isAvailable);

/// '0.1.0 (1)' — never throws; returns '–' when the plugin is unavailable.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '–';
  }
});

/// Bumped after returning from the system settings so the rows re-read.
class SettingsRefresh extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final settingsRefreshProvider = NotifierProvider<SettingsRefresh, int>(SettingsRefresh.new);
