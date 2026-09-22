import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/features/recording/live_state_provider.dart';
import 'package:dropline/platform/watch/watch.dart';

import 'fake_watch_transport.dart';

LiveState live({double drop = 0, int runs = 0, double top = 0, int elapsed = 0, double speed = 0, double? alt}) =>
    LiveState(
      stats: DayStats(dropM: drop, runCount: runs, maxSpeedMs: top, elapsedMs: elapsed),
      speedMs: speed,
      altM: alt,
    );

void main() {
  late FakeWatchTransport transport;
  late FakeClock clock;
  late ProviderContainer container;

  setUp(() {
    transport = FakeWatchTransport();
    clock = FakeClock();
    container = ProviderContainer(overrides: [
      watchTransportProvider.overrideWithValue(transport),
      watchClockProvider.overrideWithValue(clock.call),
    ]);
  });
  tearDown(() => container.dispose());

  WatchBridge bridge() => container.read(watchBridgeProvider.notifier);

  test('start sends the first context immediately, stop sends idle', () {
    bridge().start(dayId: 'day-1');
    expect(transport.contexts, hasLength(1));
    expect(transport.contexts.single['status'], 'recording');
    expect(transport.contexts.single['dayId'], 'day-1');
    expect(container.read(watchBridgeProvider).active, isTrue);

    bridge().stop();
    expect(transport.contexts.last['status'], 'idle');
    expect(transport.contexts.last.containsKey('dayId'), isFalse);
    expect(container.read(watchBridgeProvider).active, isFalse);
  });

  test('throttles live pushes to one every 2 s', () {
    final b = bridge();
    b.start(dayId: 'day-1');
    expect(transport.contexts, hasLength(1));

    b.pushLive(live(drop: 10, runs: 1));
    clock.advance(500);
    b.pushLive(live(drop: 20, runs: 1));
    clock.advance(500);
    b.pushLive(live(drop: 30, runs: 1));
    clock.advance(900);
    b.pushLive(live(drop: 40, runs: 1));
    expect(transport.contexts, hasLength(1), reason: 'nothing within the first 2 s');

    clock.advance(100); // now exactly 2000 ms after the start context
    b.pushLive(live(drop: 50, runs: 2, top: 22.5, elapsed: 2000, speed: 9.5, alt: 1900));
    expect(transport.contexts, hasLength(2));
    final ctx = transport.contexts.last;
    expect(ctx['dropM'], 50);
    expect(ctx['runCount'], 2);
    expect(ctx['maxSpeedMs'], 22.5);
    expect(ctx['elapsedMs'], 2000);
    expect(ctx['speedMs'], 9.5);
    expect(ctx['altM'], 1900);

    clock.advance(1999);
    b.pushLive(live(drop: 60));
    expect(transport.contexts, hasLength(2));
    clock.advance(1);
    b.pushLive(live(drop: 70));
    expect(transport.contexts, hasLength(3));

    final state = container.read(watchBridgeProvider);
    expect(state.sent, 3);
    expect(state.throttled, 5);
  });

  test('a pause-free 1 Hz day still pushes every second tick', () {
    final b = bridge();
    b.start(dayId: 'day-1');
    for (var i = 0; i < 10; i++) {
      clock.advance(1000);
      b.pushLive(live(drop: i.toDouble()));
    }
    // 1 start context + 5 throttled-through ticks
    expect(transport.contexts, hasLength(6));
  });

  test('follows liveStateProvider while started', () async {
    final b = bridge();
    b.start(dayId: 'day-1');
    final notifier = container.read(liveStateNotifierProvider.notifier);

    clock.advance(2000);
    notifier.set(live(drop: 123, runs: 3));
    await Future<void>.delayed(Duration.zero);
    expect(transport.contexts.last['dropM'], 123);
    expect(transport.contexts.last['runCount'], 3);

    b.stop();
    clock.advance(5000);
    notifier.set(live(drop: 999, runs: 9));
    await Future<void>.delayed(Duration.zero);
    expect(transport.contexts.last['status'], 'idle', reason: 'no live pushes after stop');
  });

  test('turns watch messages into commands', () async {
    final b = bridge();
    final seen = <WatchCommand>[];
    b.onCommand = seen.add;
    final fromStream = <WatchCommand>[];
    final sub = b.commands.listen(fromStream.add);

    transport.fromWatch({'cmd': 'start'});
    await Future<void>.delayed(Duration.zero);
    expect(seen, [WatchCommand.start]);
    expect(container.read(watchBridgeProvider).lastCommand, WatchCommand.start);

    transport.fromWatch({'cmd': 'end'});
    transport.fromWatch({'cmd': 'wiggle'});
    await Future<void>.delayed(Duration.zero);
    expect(seen, [WatchCommand.start, WatchCommand.end]);
    expect(fromStream, [WatchCommand.start, WatchCommand.end]);
    await sub.cancel();
  });

  test('records the last heart rate from the watch', () async {
    bridge();
    transport.fromWatch({'hr': 138});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(watchBridgeProvider).lastHeartRateBpm, 138);
  });

  test('start is idempotent', () {
    final b = bridge();
    b.start(dayId: 'day-1');
    clock.advance(10);
    b.start(dayId: 'day-1');
    expect(transport.contexts, hasLength(2), reason: 'start always forces a context');
    expect(container.read(watchBridgeProvider).active, isTrue);
    b.stop();
    expect(container.read(watchBridgeProvider).active, isFalse);
  });
}
