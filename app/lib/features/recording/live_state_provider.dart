import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';

class LiveStateNotifier extends Notifier<LiveState> {
  @override
  LiveState build() => LiveState.empty;
  void set(LiveState s) => state = s;
  void reset() => state = LiveState.empty;
}

final liveStateNotifierProvider = NotifierProvider<LiveStateNotifier, LiveState>(LiveStateNotifier.new);

/// Read-only view for screens and the Watch bridge (≈1 Hz while recording).
final liveStateProvider = Provider<LiveState>((ref) => ref.watch(liveStateNotifierProvider));
