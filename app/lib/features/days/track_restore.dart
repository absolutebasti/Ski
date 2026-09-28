import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridge from the Tag detail to SYNC-HARDENING's track restore (lib/data/sync,
/// `trackRestoreProvider(dayId)` + `track_path`). The local `days` row carries
/// no `track_path` yet, so the screen asks this bridge instead of the model.
///
/// The lead overrides [dayTrackRestoreProvider] in the app; the default `null`
/// hides 'Spur laden' (offline / signed-out / not wired).
class DayTrackRestore {
  const DayTrackRestore({required this.hasRemoteTrack, required this.restore});

  /// True when the day has a remote `track_path` worth downloading.
  final Future<bool> Function(String dayId) hasRemoteTrack;

  /// Downloads and decodes the bundle into local points/segments; the screen
  /// invalidates `dayDetailProvider(dayId)` afterwards. Throw on failure.
  final Future<void> Function(String dayId) restore;
}

final dayTrackRestoreProvider = Provider<DayTrackRestore?>((ref) => null);

/// Whether the 'Spur laden' affordance applies to [dayId] (points are checked
/// by the caller). False whenever the bridge is not wired.
final dayHasRemoteTrackProvider = FutureProvider.autoDispose.family<bool, String>((ref, dayId) async {
  final bridge = ref.watch(dayTrackRestoreProvider);
  if (bridge == null) return false;
  try {
    return await bridge.hasRemoteTrack(dayId);
  } on Object {
    return false;
  }
});
