import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schwung/core/core.dart';
import 'package:schwung/platform/providers.dart';
import 'package:schwung/platform/watch/watch.dart';

import 'fake_watch_transport.dart';

void main() {
  test('forwards only plausible heart rates', () async {
    final transport = FakeWatchTransport();
    final source = WatchHeartRateSource(transport);
    final got = <int>[];
    final sub = source.bpm.listen(got.add);

    transport.fromWatch({'hr': 120});
    transport.fromWatch({'cmd': 'start'});
    transport.fromWatch({'hr': 999});
    transport.fromWatch({'hr': 131.4});
    await Future<void>.delayed(Duration.zero);

    expect(got, [120, 131]);
    await sub.cancel();
  });

  test('can replace heartRateSourceProvider', () {
    final transport = FakeWatchTransport();
    final container = ProviderContainer(overrides: [
      watchTransportProvider.overrideWithValue(transport),
      heartRateSourceProvider.overrideWith((ref) => WatchHeartRateSource(ref.watch(watchTransportProvider))),
    ]);
    addTearDown(container.dispose);

    final src = container.read(heartRateSourceProvider);
    expect(src, isA<WatchHeartRateSource>());
    expect(src, isA<HeartRateSource>());
  });
}
