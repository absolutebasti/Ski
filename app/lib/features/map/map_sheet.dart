import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../recording/live_state_provider.dart';
import '../recording/live_track_provider.dart';
import 'map_strings.dart';
import 'track_map.dart';

/// Full-height live map over the ring of recent points (PLAN §3 'Karte').
class MapSheet {
  const MapSheet._();

  static Future<void> show(BuildContext context) =>
      AppSheet.show<void>(context, expand: true, builder: (_) => const MapSheetBody());
}

/// Exposed for tests; use [MapSheet.show] in the app.
class MapSheetBody extends ConsumerStatefulWidget {
  const MapSheetBody({super.key, this.tilesEnabled = true});
  final bool tilesEnabled;

  @override
  ConsumerState<MapSheetBody> createState() => _MapSheetBodyState();
}

class _MapSheetBodyState extends ConsumerState<MapSheetBody> {
  final ValueNotifier<int> _locate = ValueNotifier(0);

  @override
  void dispose() {
    _locate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = MapStrings.of(context);
    final points = ref.watch(liveTrackProvider);
    final live = ref.watch(liveStateProvider);
    final hasFix = points.any((p) => p.accepted && p.hasPosition);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Tokens.radiusLg)),
      child: ColoredBox(
        color: c.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: TrackMap(
                points: points,
                segments: const [],
                follow: true,
                tilesEnabled: widget.tilesEnabled,
                locateSignal: _locate,
              ),
            ),
            // Top bar: close · title · locate
            Positioned(
              left: Tokens.pad - 8,
              right: Tokens.pad - 8,
              top: 12,
              child: Row(
                children: [
                  _RoundButton(icon: Icons.close_rounded, tooltip: s.close, onPressed: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  Text(s.title, style: AppText.title(c.textPrimary, size: 17)),
                  const Spacer(),
                  _RoundButton(icon: Icons.my_location_rounded, tooltip: s.locate, onPressed: hasFix ? () => _locate.value++ : null),
                ],
              ),
            ),
            // Bottom readout: state · speed · altitude
            Positioned(
              left: Tokens.pad,
              right: Tokens.pad,
              bottom: Tokens.pad,
              child: _LiveReadout(live: live, hasFix: hasFix),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveReadout extends StatelessWidget {
  const _LiveReadout({required this.live, required this.hasFix});
  final LiveState live;
  final bool hasFix;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = MapStrings.of(context);
    final locale = AppLocale.of(context).code;
    if (!hasFix) {
      return AppCard(
        elevated: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(s.waitingForGps, style: AppText.bodyText(c.textSecondary, size: 15), textAlign: TextAlign.center),
      );
    }
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _Stat(label: s.speed, value: Fmt.kmh(live.speedMs, locale: locale), unit: 'km/h')),
          Container(width: 1, height: 28, color: c.hairline),
          Expanded(child: _Stat(label: s.altitude, value: live.altM == null ? '–' : Fmt.metres(live.altM!, locale: locale), unit: 'm')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit});
  final String label, value, unit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AppText.label(c.textTertiary)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppText.stat(c.textPrimary, size: 24)),
            const SizedBox(width: 4),
            Text(unit, style: AppText.unit(c.textSecondary, size: 13)),
          ],
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: c.elevated.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: Tokens.minTarget - 8,
            height: Tokens.minTarget - 8,
            child: Icon(icon, size: 24, color: enabled ? c.textPrimary : c.textTertiary),
          ),
        ),
      ),
    );
  }
}
