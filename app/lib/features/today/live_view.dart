import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../map/map_sheet.dart';
import '../recording/live_state_provider.dart';
import 'today_strings.dart';

/// Heute while a day is running: pill, state chip, three hero numbers, the
/// secondary row, the time bar and the two buttons (docs/PLAN.md §3, §11).
/// Nothing moves here except the recording dot and the run banner.
class LiveView extends ConsumerWidget {
  const LiveView({super.key, required this.onEnd, this.banner, this.busy = false});

  final VoidCallback onEnd;
  final String? banner;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final live = ref.watch(liveStateProvider);
    final st = live.stats;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 4, Tokens.pad, 8),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RecordingPill(text: s.recordingPill(live.gps)),
                  _StateChip(live: live),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(height: 44, child: _RunBanner(text: banner)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Hero(
                      value: Fmt.metres(st.dropM, locale: l.code),
                      unit: s.unitHm,
                      label: s.vertical,
                    ),
                  ),
                  Expanded(child: _Hero(value: '${st.runCount}', label: s.runs)),
                  Expanded(
                    child: _Hero(
                      value: Fmt.kmh(st.maxSpeedMs, locale: l.code),
                      unit: s.unitKmh,
                      label: s.topSpeed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: HeroNumber(
                          value: Fmt.kmh(live.speedMs, locale: l.code),
                          unit: s.unitKmh,
                          label: s.speed,
                          size: 40,
                          color: c.ice,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: StatTile(
                      value: live.altM == null ? s.dash : Fmt.metres(live.altM!, locale: l.code),
                      unit: live.altM == null ? null : s.unitM,
                      label: s.altitude,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: StatTile(value: Fmt.clock(st.elapsedMs), label: s.time),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              StackedTimeBar(
                skiMs: st.skiMs,
                liftMs: st.liftMs,
                pauseMs: st.pauseMs,
                signalLossMs: st.signalLossMs,
                otherMs: st.otherMs,
                labels: s.timeBarLabels,
              ),
              if (live.batteryEtaTs != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.battery_5_bar_rounded, size: 14, color: c.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      s.batteryEta(Fmt.timeOfDay(live.batteryEtaTs!, locale: l.code)),
                      style: AppText.label(c.textTertiary, size: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, Tokens.pad),
          child: Row(
            children: [
              SecondaryButton(
                label: s.map,
                icon: Icons.map_outlined,
                onPressed: () => MapSheet.show(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HoldToConfirmButton(
                  label: s.end,
                  onConfirmed: busy ? () {} : onEnd,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 88 pt in the spec, 56 here so three fit next to each other on 375 pt;
/// the FittedBox keeps '1.804' on one line on the narrowest phones.
class _Hero extends StatelessWidget {
  const _Hero({required this.value, required this.label, this.unit});
  final String value;
  final String label;
  final String? unit;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: HeroNumber(value: value, unit: unit, label: label, size: 56),
      );
}

/// 'Abfahrt 7' / 'Im Lift' / 'Pause' / 'Kein GPS – Höhe über Barometer'.
class _StateChip extends StatelessWidget {
  const _StateChip({required this.live});
  final LiveState live;

  @override
  Widget build(BuildContext context) {
    final s = TodayStrings.of(context);
    if (live.gps == GpsQuality.none) {
      return StateChip(
        text: live.altM == null ? s.noGps : s.noGpsBaro,
        tone: ChipTone.danger,
        icon: Icons.satellite_alt_outlined,
      );
    }
    final (text, tone, icon) = switch (live.state) {
      MotionState.run => (s.runLabel(live.stats.runCount), ChipTone.accent, Icons.downhill_skiing_rounded),
      MotionState.lift => (s.inLift, ChipTone.ice, Icons.airline_seat_recline_normal_rounded),
      MotionState.stop => (s.pause, ChipTone.neutral, Icons.pause_rounded),
      MotionState.other => (s.moving, ChipTone.neutral, Icons.directions_walk_rounded),
      MotionState.unknown => (s.moving, ChipTone.neutral, Icons.more_horiz_rounded),
    };
    return StateChip(text: text, tone: tone, icon: icon);
  }
}

/// 'Abfahrt 7 · 312 hm · 61 km/h' — 3 s after a run is committed.
class _RunBanner extends StatelessWidget {
  const _RunBanner({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedSwitcher(
      duration: Tokens.fast,
      child: text == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(text),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(Tokens.radius),
              ),
              child: Text(text!, style: AppText.bodyText(c.accent, size: 15, weight: FontWeight.w600)),
            ),
    );
  }
}
