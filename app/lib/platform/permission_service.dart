import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum LocationPermissionState { always, whileInUse, denied, deniedForever, unknown }

/// Thin wrapper so features and tests never touch the plugins directly.
abstract class PermissionService {
  Future<LocationPermissionState> status();
  Future<LocationPermissionState> requestWhenInUse();
  /// Call only after WhenInUse was granted; iOS shows the "Change to Always" dialog once.
  Future<LocationPermissionState> requestAlways();
  /// iOS Motion & Fitness (needed by CMAltimeter). Android: always true.
  Future<bool> requestMotion();
  Future<bool> requestNotifications();
  Future<bool> notificationsGranted();
  Future<bool> hasPreciseLocation();
  Future<bool> requestTemporaryFullAccuracy();
  Future<bool> isLocationServiceEnabled();
  Future<void> openSettings();
}

class PluginPermissionService implements PermissionService {
  LocationPermissionState _map(ph.PermissionStatus s, {required bool always}) => switch (s) {
        ph.PermissionStatus.granted => always ? LocationPermissionState.always : LocationPermissionState.whileInUse,
        ph.PermissionStatus.limited => LocationPermissionState.whileInUse,
        ph.PermissionStatus.provisional => LocationPermissionState.always,
        ph.PermissionStatus.permanentlyDenied => LocationPermissionState.deniedForever,
        ph.PermissionStatus.restricted => LocationPermissionState.deniedForever,
        ph.PermissionStatus.denied => LocationPermissionState.denied,
      };

  @override
  Future<LocationPermissionState> status() async {
    final always = await ph.Permission.locationAlways.status;
    if (always.isGranted) return LocationPermissionState.always;
    final wiu = await ph.Permission.locationWhenInUse.status;
    return _map(wiu, always: false);
  }

  @override
  Future<LocationPermissionState> requestWhenInUse() async {
    final s = await ph.Permission.locationWhenInUse.request();
    return _map(s, always: false);
  }

  @override
  Future<LocationPermissionState> requestAlways() async {
    final s = await ph.Permission.locationAlways.request();
    if (s.isGranted) return LocationPermissionState.always;
    // Not upgraded: keep whatever WhenInUse state we have.
    return status();
  }

  @override
  Future<bool> requestMotion() async {
    if (!Platform.isIOS) return true;
    final s = await ph.Permission.sensors.request();
    return s.isGranted || s.isLimited;
  }

  @override
  Future<bool> requestNotifications() async {
    final s = await ph.Permission.notification.request();
    return s.isGranted || s.isProvisional;
  }

  @override
  Future<bool> notificationsGranted() async {
    final s = await ph.Permission.notification.status;
    return s.isGranted || s.isProvisional;
  }

  @override
  Future<bool> hasPreciseLocation() async {
    try {
      final a = await Geolocator.getLocationAccuracy();
      return a == LocationAccuracyStatus.precise;
    } catch (_) {
      return true; // Android < 12 / unsupported: treat as precise
    }
  }

  @override
  Future<bool> requestTemporaryFullAccuracy() async {
    try {
      final a = await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'Tracking');
      return a == LocationAccuracyStatus.precise;
    } catch (_) {
      return hasPreciseLocation();
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<void> openSettings() async {
    await ph.openAppSettings();
  }
}
