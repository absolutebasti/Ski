import 'dart:io';

import 'package:flutter/services.dart';

/// iOS significant-location-change watchdog (ios/Runner/TrackingWatchdog.swift).
/// With "Always" permission iOS relaunches the app after a kill when the user
/// moves ~500 m; main() then resumes the active day. No-op on Android.
abstract class WatchdogChannel {
  Future<void> start();
  Future<void> stop();
  Future<bool> didLaunchFromLocation();
}

class MethodChannelWatchdog implements WatchdogChannel {
  static const _channel = MethodChannel('de.torchtechnology.slopetrack/watchdog');

  @override
  Future<void> start() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('start');
    } on MissingPluginException {
      // simulator / old build without the Swift side
    }
  }

  @override
  Future<void> stop() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } on MissingPluginException {
      // ignore
    }
  }

  @override
  Future<bool> didLaunchFromLocation() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('didLaunchFromLocation') ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
