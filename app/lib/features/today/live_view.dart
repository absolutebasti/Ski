import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../map/map_sheet.dart';
import '../recording/live_state_provider.dart';
import 'today_strings.dart';

/// Heute while a day is running (docs/DESIGN.md §5 "Heute — live"): pure-black
/// glare theme, one 92 pt lead number, a tempo strip and the hold-to-end dock.
/// Nothing moves here except the recording dot and the run banner.
class LiveView extends StatelessWidget {
  const LiveView({super.key, required this.onEnd, this.banner, this.bannerRun, this.busy = false});

  final VoidCallback onEnd;
  /// Full sentence for the run banner ('Abfahrt 7 · 312 hm · 61 km/h').
  final String? banner;
  /// The run behind [banner]; drives the typeset banner when present.
  final Segment? bannerRun;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: glareTheme(),
      child: Builder(
        builder: (context) {
          final c = AppColors.of(context);
          return MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            maxScaleFactor: 1.35,
            child: ColoredBox(
              color: c.bg,
              child: SafeArea(
                bottom: false,
                child: _LiveBody(onEnd: onEnd, banner: banner, bannerRun: bannerRun, busy: busy),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LiveBody extends ConsumerWidget {
  const _LiveBody({required this.onEnd, required this.banner, required this.bannerRun, required this.busy});

  final VoidCallback onEnd;
  final String? banner;
  final Segment? bannerRun;
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
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(Tokens.pad, 4, Tokens.pad, 12),
                children: [
                  _StatusRow(live: live),
                  const SizedBox(height: 18),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: HeroNumber(
                      value: Fmt.metres(st.dropM, locale: l.code),
                      unit: s.unitHm,
                      label: s.vertical,
                      size: 92,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: HeroNumber(value: '${st.runCount}', label: s.runs, size: 34)),
                      Expanded(
                        child: HeroNumber(
                          value: Fmt.kmh(st.maxSpeedMs, locale: l.code),
                          unit: s.unitKmh,
                          label: s.topSpeed,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _TempoStrip(speedMs: live.speedMs, dayMaxMs: st.maxSpeedMs),
                  const SizedBox(height: Tokens.cardGap),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: live.altM == null ? s.dash : Fmt.metres(live.altM!, locale: l.code),
                          unit: live.altM == null ? null : s.unitM,
                          label: s.altitude,
                        ),
                      ),
                      const SizedBox(width: Tokens.cardGap),
                      Expanded(child: StatTile(value: Fmt.clock(st.elapsedMs), label: s.time)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  StackedTimeBar(
                    skiMs: st.skiMs,
                    liftMs: st.liftMs,
                    pauseMs: st.pauseMs,
                    signalLossMs: st.signalLossMs,
                    otherMs: st.otherMs,
                    labels: s.timeBarLabels,
                  ),
                  if (live.batteryEtaTs != null) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(Icons.battery_5_bar_rounded, size: 14, color: c.textTertiary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            s.batteryEta(Fmt.timeOfDay(live.batteryEtaTs!, locale: l.code)),
                            style: AppText.label(c.textTertiary, size: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              // Slides down over the status row — no reserved gap in the layout.
              Positioned(
                left: Tokens.pad,
                right: Tokens.pad,
                top: 0,
                child: RunBanner(text: banner, run: bannerRun),
              ),
            ],
          ),
        ),
        BottomDock(
          child: Row(
            children: [
              Semantics(
                button: true,
                label: s.map,
                child: SecondaryButton(
                  label: '',
                  glyph: Glyph.map,
                  height: Tokens.minTarget,
                  onPressed: () => MapSheet.show(context),
                ),
              ),
              const SizedBox(width: Tokens.cardGap),
              Expanded(child: HoldToConfirmButton(label: s.end, onConfirmed: busy ? () {} : onEnd)),
            ],
          ),
        ),
      ],
    );
  }
}

/// h 40: recording pill + state chip, scaled down together on narrow phones.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.live});
  final LiveState live;

  @override
  Widget build(BuildContext context) {
    final s = TodayStrings.of(context);
    return SizedBox(
      height: 40,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RecordingPill(text: s.recordingPill(live.gps)),
            const SizedBox(width: 8),
            _StateChip(live: live),
          ],
        ),
      ),
    );
  }
}

/// TEMPO: 56 pt ice numeral plus a 24 pt bar from 0 to the day's maximum.
class _TempoStrip extends StatelessWidget {
  const _TempoStrip({required this.speedMs, required this.dayMaxMs});
  final double speedMs;
  final double dayMaxMs;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    return AppCard(
      tone: CardTone.ice,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: HeroNumber(
              value: Fmt.kmh(speedMs, locale: l.code),
              unit: s.unitKmh,
              label: s.tempo,
              size: 56,
              color: c.ice,
            ),
          ),
          const SizedBox(height: 12),
          SpeedBar(value: speedMs, max: dayMaxMs),
        ],
      ),
    );
  }
}

/// 24 pt track, ice fill to [value] / [max] and a 2 pt head at the tip.
class SpeedBar extends StatelessWidget {
  const SpeedBar({super.key, required this.value, required this.max, this.height = 24});
  final double value;
  final double max;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final f = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height / 2);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.ice.withValues(alpha: 0.14), borderRadius: radius),
                ),
              ),
              if (f > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: (w * f).clamp(height, w),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: c.ice.withValues(alpha: 0.5), borderRadius: radius),
                  ),
                ),
              if (f > 0)
                Positioned(
                  left: (w * f - 2).clamp(0.0, w - 2),
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: ColoredBox(color: c.ice),
                ),
            ],
          ),
        );
      },
    );
  }
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
        icon: Icons.satellite_alt_rounded,
      );
    }
    final c = AppColors.of(context);
    final (text, tone, glyph, icon) = switch (live.state) {
      MotionState.run => (s.runLabel(live.stats.runCount), ChipTone.accent, Glyph.slalom, null),
      MotionState.lift => (s.inLift, ChipTone.ice, Glyph.chairlift, null),
      MotionState.stop => (s.pause, ChipTone.neutral, null, Icons.pause_rounded),
      MotionState.other => (s.moving, ChipTone.neutral, null, Icons.directions_walk_rounded),
      MotionState.unknown => (s.moving, ChipTone.neutral, null, Icons.more_horiz_rounded),
    };
    final colour = switch (tone) {
      ChipTone.accent => c.accent,
      ChipTone.ice => c.ice,
      ChipTone.danger => c.danger,
      ChipTone.neutral => c.textSecondary,
    };
    return StateChip(
      text: text,
      tone: tone,
      icon: icon,
      child: glyph == null ? null : GlyphIcon(glyph, size: 14, color: colour),
    );
  }
}

/// Run committed: slides down 12 pt and fades in over the status row, holds
/// while [text] is set, then fades out and leaves the tree.
class RunBanner extends StatefulWidget {
  const RunBanner({super.key, required this.text, this.run});
  final String? text;
  final Segment? run;

  @override
  State<RunBanner> createState() => _RunBannerState();
}

class _RunBannerState extends State<RunBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  String? _shown;
  Segment? _shownRun;

  @override
  void initState() {
    super.initState();
    if (widget.text != null) {
      _shown = widget.text;
      _shownRun = widget.run;
      _ctrl.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant RunBanner old) {
    super.didUpdateWidget(old);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.text != null && widget.text != _shown) {
      _shown = widget.text;
      _shownRun = widget.run;
      if (reduce) {
        _ctrl.value = 1;
      } else {
        _ctrl.forward(from: 0);
      }
    } else if (widget.text == null && _shown != null) {
      if (reduce) {
        _ctrl.value = 0;
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final text = _shown;
        if (text == null || _ctrl.value == 0) return const SizedBox.shrink();
        final run = _shownRun;
        final t = _ctrl.value;
        return IgnorePointer(
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, -12 * (1 - t)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: ShapeDecoration(
                  color: Color.alphaBlend(c.accentWash, c.surface),
                  shape: Squircle.border(Tokens.r20, side: c.accent.withValues(alpha: 0.45), width: c.hairlineWidth),
                ),
                child: run == null
                    ? Text(text, style: AppText.bodyStrong(c.accent, size: 15), maxLines: 1, overflow: TextOverflow.ellipsis)
                    : Row(
                        children: [
                          GlyphIcon(Glyph.slalom, size: 18, color: c.accent),
                          const SizedBox(width: 10),
                          Text('${run.runNumber ?? 0}', style: AppText.numS(c.accent)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.runBannerMetrics(
                                dropM: Fmt.metres(run.dropM, locale: l.code),
                                kmh: Fmt.kmh(run.maxSpeedMs, locale: l.code),
                              ),
                              style: AppText.bodyStrong(c.textPrimary, size: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
