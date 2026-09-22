import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: reminders, idle/vehicle auto-end, battery, day summary.
/// Permission is requested contextually via PermissionService, never here.
abstract class NotificationService {
  Future<void> init();
  Future<void> showReminder(int id, String title, String body);
  Future<void> scheduleIn(int id, Duration delay, String title, String body);
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

class NotificationIds {
  const NotificationIds._();
  static const dayReminder = 1;
  static const idle = 2;
  static const battery = 3;
  static const vehicle = 4;
  static const summary = 5;
}

class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true),
    android: AndroidNotificationDetails('schwung_tracking', 'Aufnahme', channelDescription: 'Hinweise während eines Skitags', importance: Importance.high, priority: Priority.high),
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    _ready = true;
  }

  @override
  Future<void> showReminder(int id, String title, String body) async {
    await init();
    await _plugin.show(id: id, title: title, body: body, notificationDetails: _details);
  }

  @override
  Future<void> scheduleIn(int id, Duration delay, String title, String body) async {
    await init();
    final when = tz.TZDateTime.now(tz.UTC).add(delay);
    await _plugin.zonedSchedule(id: id, title: title, body: body, scheduledDate: when, notificationDetails: _details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
