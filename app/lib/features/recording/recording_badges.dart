import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/widgets/widgets.dart';
import 'recording_access.dart';
import 'recording_strings.dart';

/// Danger chip while location access is lost mid-day; empty otherwise.
/// Mount next to the state chip in the live view.
class TrackingAccessChip extends ConsumerWidget {
  const TrackingAccessChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(trackingAccessProvider);
    if (!access.lost) return const SizedBox.shrink();
    return StateChip(text: RecordingStrings.of(context).accessChip(access.access), tone: ChipTone.danger, icon: Icons.location_off_rounded);
  }
}

/// 'GPS-Höhe' chip when the altitude comes from GPS only (no barometer or
/// Motion & Fitness denied); empty otherwise.
class GpsAltitudeBadge extends ConsumerWidget {
  const GpsAltitudeBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(gpsAltitudeOnlyProvider)) return const SizedBox.shrink();
    return StateChip(text: RecordingStrings.of(context).gpsAltitudeBadge, icon: Icons.terrain_rounded);
  }
}

/// Shows each pending one-line hint as a toast once, then consumes them.
/// Mount anywhere below the app's Overlay (e.g. in the Heute screen tree).
class RecordingHintToaster extends ConsumerWidget {
  const RecordingHintToaster({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<RecordingHints>(recordingHintsProvider, (_, hints) {
      if (hints.pending.isEmpty) return;
      final s = RecordingStrings.of(context);
      for (final h in hints.pending) {
        showToast(context, s.hint(h), icon: h == RecordingHint.lowPowerMode ? Icons.battery_saver_rounded : Icons.terrain_rounded);
      }
      ref.read(recordingHintsProvider.notifier).consume();
    });
    return child ?? const SizedBox.shrink();
  }
}
