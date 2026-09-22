import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/features/recording/recording_controller.dart';
import 'package:dropline/platform/watch/watch.dart';

import 'fake_watch_transport.dart';

/// Stands in for WP-05's controller: same provider, no database.
class FakeRecordingController extends RecordingController {
  final List<String> calls = [];
  bool failStart = false;

  @override
  RecordingState build() => RecordingState.idle;

  @override
  Future<void> startDay() async {
    calls.add('start');
    if (failStart) throw const RecordingError(RecordingErrorKind.locationDenied);
    state = const RecordingState(status: RecordingStatus.recording, dayId: 'day-x', startedAt: 1);
  }

  @override
  Future<String?> endDay({int? trimTrailingIdleFrom}) async {
    calls.add('end');
    state = RecordingState.idle;
    return 'day-x';
  }
}

void main() {
  late FakeWatchTransport transport;
  late FakeClock clock;
  late FakeRecordingController controller;
  late ProviderContainer container;

  setUp(() {
    transport = FakeWatchTransport();
    clock = FakeClock();
    controller = FakeRecordingController();
    container = ProviderContainer(overrides: [
      watchTransportProvider.overrideWithValue(transport),
      watchClockProvider.overrideWithValue(clock.call),
      recordingControllerProvider.overrideWith(() => controller),
    ]);
  });
  tearDown(() => container.dispose());

  test('attach runs a wrist Start and follows the controller', () async {
    container.read(watchBridgeProvider.notifier).attach();
    expect(transport.contexts, isEmpty);

    transport.fromWatch({'cmd': 'start'});
    await Future<void>.delayed(Duration.zero);

    expect(controller.calls, ['start']);
    expect(container.read(watchBridgeProvider).active, isTrue);
    expect(transport.contexts.last['status'], 'recording');
    expect(transport.contexts.last['dayId'], 'day-x');

    transport.fromWatch({'cmd': 'end'});
    await Future<void>.delayed(Duration.zero);

    expect(controller.calls, ['start', 'end']);
    expect(container.read(watchBridgeProvider).active, isFalse);
    expect(transport.contexts.last['status'], 'idle');
  });

  test('a rejected start tells the wrist we are still idle', () async {
    controller.failStart = true;
    container.read(watchBridgeProvider.notifier).attach();

    transport.fromWatch({'cmd': 'start'});
    await Future<void>.delayed(Duration.zero);

    expect(controller.calls, ['start']);
    expect(container.read(watchBridgeProvider).active, isFalse);
    expect(transport.contexts.last['status'], 'idle');
  });

  test('attach is idempotent and keeps a handler the app installed itself', () async {
    final bridge = container.read(watchBridgeProvider.notifier);
    final seen = <WatchCommand>[];
    bridge.onCommand = seen.add;
    bridge.attach();
    bridge.attach();

    transport.fromWatch({'cmd': 'start'});
    await Future<void>.delayed(Duration.zero);
    expect(seen, [WatchCommand.start]);
    expect(controller.calls, isEmpty, reason: 'the app-provided handler wins');
  });
}
