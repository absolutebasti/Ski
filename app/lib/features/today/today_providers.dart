import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/providers.dart';
import '../recording/recording_controller.dart';

/// Resort name of the day being recorded, read from the active `days` row.
///
/// Null while idle and until the controller resolves a resort (it retries
/// every 60 s, so this polls the row every [pollInterval] until a name shows
/// up, then stops). The Heute caption must never fall back to the *last*
/// resort while a day is running — that name may be stale.
final activeDayResortProvider = StreamProvider.autoDispose<String?>((ref) {
  final recording = ref.watch(recordingControllerProvider);
  if (!recording.isRecording) return Stream.value(null);
  final repo = ref.watch(daysRepositoryProvider);
  final ctrl = StreamController<String?>();
  Timer? timer;

  Future<void> poll() async {
    String? name;
    try {
      name = (await repo.activeDay())?.resortName;
    } on Object {
      name = null;
    }
    if (ctrl.isClosed) return;
    ctrl.add(name);
    if (name == null) timer = Timer(activeResortPollInterval, poll);
  }

  ref.onDispose(() {
    timer?.cancel();
    ctrl.close();
  });
  unawaited(poll());
  return ctrl.stream;
});

/// How often the active row is re-read while its resort is still unresolved.
const Duration activeResortPollInterval = Duration(seconds: 30);
