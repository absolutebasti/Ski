import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import 'barometer_source.dart';
import 'battery_source.dart';
import 'location_source.dart';
import 'notification_service.dart';
import 'permission_service.dart';
import 'watchdog_channel.dart';

final locationSourceProvider = Provider<LocationSource>((ref) => GeolocatorLocationSource());
final barometerSourceProvider = Provider<BarometerSource>((ref) => SensorsBarometerSource());
final batterySourceProvider = Provider<BatterySource>((ref) => BatteryPlusSource());
final heartRateSourceProvider = Provider<HeartRateSource>((ref) => NoopHeartRateSource());
final permissionServiceProvider = Provider<PermissionService>((ref) => PluginPermissionService());
final notificationServiceProvider = Provider<NotificationService>((ref) => LocalNotificationService());
final watchdogChannelProvider = Provider<WatchdogChannel>((ref) => MethodChannelWatchdog());
