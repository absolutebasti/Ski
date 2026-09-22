import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Thin seam over `watch_connectivity` so the bridge can be tested without
/// method channels. One instance per app; [messages] is a broadcast stream.
abstract class WatchTransport {
  /// Messages received from the watch (`{cmd: ...}`, `{hr: ...}`).
  Stream<Map<String, dynamic>> get messages;

  /// Latest-value-wins payload for the watch. Safe to call often.
  Future<void> updateContext(Map<String, dynamic> context);

  /// Direct message to the watch (only when reachable).
  Future<void> sendMessage(Map<String, dynamic> message);

  /// False on Android/desktop and when no watch is paired.
  Future<bool> get isAvailable;

  Future<void> dispose();
}

/// Production implementation. Every plugin call is guarded: on a phone without
/// a paired watch — or on a platform without the plugin — the bridge must stay
/// silent rather than throw into the recording controller.
class WatchConnectivityTransport implements WatchTransport {
  WatchConnectivityTransport([WatchConnectivity? client]) : _client = client ?? WatchConnectivity() {
    _sub = _client.messageStream.listen(
      (m) => _messages.add(Map<String, dynamic>.from(m)),
      onError: (_) {},
    );
  }

  final WatchConnectivity _client;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Future<bool> get isAvailable async {
    try {
      return await _client.isSupported && await _client.isPaired;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> updateContext(Map<String, dynamic> context) async {
    try {
      await _client.updateApplicationContext(context);
    } on MissingPluginException {
      // no watch plugin on this platform
    } on PlatformException {
      // no session / no paired watch
    }
  }

  @override
  Future<void> sendMessage(Map<String, dynamic> message) async {
    try {
      await _client.sendMessage(message);
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // watch not reachable
    }
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _messages.close();
  }
}

/// Single shared transport; override in tests and in phone-only unit tests.
final watchTransportProvider = Provider<WatchTransport>((ref) {
  final t = WatchConnectivityTransport();
  ref.onDispose(t.dispose);
  return t;
});

/// Wall clock in ms, injectable so the 2 s throttle can be tested.
typedef WatchClock = int Function();

final watchClockProvider = Provider<WatchClock>((ref) => () => DateTime.now().millisecondsSinceEpoch);
