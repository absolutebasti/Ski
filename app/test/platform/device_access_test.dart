import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/platform/device_access.dart';
import 'package:slopetrack/platform/notification_service.dart';
import 'package:slopetrack/platform/providers.dart';

/// The plugin-backed source must never block a recording when a plugin is
/// missing (tests, desktop, simulator without sensors).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final src = PluginDeviceAccessSource();

  test('motion permission falls back to granted off iOS / without the plugin', () async {
    expect(await src.isMotionGranted(), isTrue);
  });

  test('Low Power Mode falls back to false without the plugin', () async {
    expect(await src.isLowPowerMode(), isFalse);
  });

  test('service-status stream can be listened to and cancelled without an error', () async {
    final events = <bool>[];
    final sub = src.locationServiceChanges.listen(events.add, onError: (Object e) => fail('stream must not error: $e'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(events, isEmpty);
  });

  test('deviceAccessProvider defaults to the plugin source', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(deviceAccessProvider), isA<PluginDeviceAccessSource>());
  });

  test('notification ids are unique and the access id is new', () {
    const ids = [NotificationIds.dayReminder, NotificationIds.idle, NotificationIds.battery, NotificationIds.vehicle, NotificationIds.summary, NotificationIds.access];
    expect(ids.toSet().length, ids.length);
    expect(NotificationIds.access, 6);
  });
}
