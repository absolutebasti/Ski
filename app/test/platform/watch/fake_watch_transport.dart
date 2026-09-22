import 'dart:async';

import 'package:schwung/platform/watch/watch.dart';

/// In-memory stand-in for WatchConnectivity.
class FakeWatchTransport implements WatchTransport {
  final _in = StreamController<Map<String, dynamic>>.broadcast();

  /// Every application context handed to the watch, oldest first.
  final List<Map<String, dynamic>> contexts = [];
  final List<Map<String, dynamic>> sentMessages = [];
  bool available = true;
  bool disposed = false;

  @override
  Stream<Map<String, dynamic>> get messages => _in.stream;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<void> updateContext(Map<String, dynamic> context) async => contexts.add(context);

  @override
  Future<void> sendMessage(Map<String, dynamic> message) async => sentMessages.add(message);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _in.close();
  }

  /// Simulate the watch app sending a message.
  void fromWatch(Map<String, dynamic> message) => _in.add(message);
}

/// Controllable wall clock for the throttle tests.
class FakeClock {
  FakeClock([this.ms = 1000000]);
  int ms;
  int call() => ms;
  void advance(int by) => ms += by;
}
