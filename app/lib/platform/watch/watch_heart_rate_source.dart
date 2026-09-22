import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import 'watch_messages.dart';
import 'watch_transport.dart';

/// Heart rate streamed from the Watch workout session (`{hr: bpm}`).
///
/// The recording controller consumes it through `heartRateSourceProvider`;
/// wire it up in `main.dart` with
/// `heartRateSourceProvider.overrideWith((ref) => WatchHeartRateSource(ref.watch(watchTransportProvider)))`.
class WatchHeartRateSource implements HeartRateSource {
  WatchHeartRateSource(this._transport);

  final WatchTransport _transport;

  @override
  Stream<int> get bpm => _transport.messages
      .map(watchHeartRateFrom)
      .where((v) => v != null)
      .cast<int>();
}

/// Ready-made override for `heartRateSourceProvider` (see main.dart).
final watchHeartRateSourceProvider =
    Provider<HeartRateSource>((ref) => WatchHeartRateSource(ref.watch(watchTransportProvider)));
