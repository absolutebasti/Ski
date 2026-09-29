import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/db/providers.dart';
import '../../platform/providers.dart';
import '../achievements/achievements.dart';
import '../achievements/ui/ui.dart';
import '../share/share_service.dart';
import '../social/duel/duel.dart';
import '../social/leaderboard_providers.dart';
import 'count_up.dart';
import 'mascot_line.dart';
import 'notifications_sheet.dart';
import 'route_block.dart';
import 'summary_skeleton.dart';
import 'summary_strings.dart';
import 'time_legend.dart';

/// Full-screen route right after "Tag beenden" (docs/DESIGN.md §5
/// "Tagesbilanz"): the route draws itself, the numbers count up, a record gets
/// one solid champagne moment and Leo has the last word.
class TagesbilanzScreen extends ConsumerStatefulWidget {
  const TagesbilanzScreen({super.key, required this.dayId});
  final String dayId;

  @override
  ConsumerState<TagesbilanzScreen> createState() => _TagesbilanzScreenState();
}

class _TagesbilanzScreenState extends ConsumerState<TagesbilanzScreen> with SingleTickerProviderStateMixin {
  static const int _steps = 4;

  // Created eagerly: a lazy `late` would first run in dispose() when the day
  // never resolved (skeleton shown, screen left) and look up TickerMode on a
  // deactivated element.
  late final AnimationController _ctrl;
  bool _started = false;
  bool _hapticDone = false;
  bool _askedNotifications = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: countUpTotal(_steps));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Runs once, after the day is on screen.
  void _onFirstData({required bool isPb}) {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _ctrl.value = 1;
      } else {
        _ctrl.forward(from: 0);
      }
      if (isPb && !_hapticDone) {
        _hapticDone = true;
        unawaited(HapticFeedback.heavyImpact());
      }
    });
  }

  /// Asked once, on 'Fertig' — never while the numbers are still counting.
  /// Dismissing the sheet counts as 'Nicht jetzt' so it does not return daily.
  Future<void> _maybeAskNotifications() async {
    if (_askedNotifications) return;
    _askedNotifications = true;
    if (ref.read(settingsProvider).notificationsAsked) return;
    final wants = await NotificationsOptInSheet.show(context);
    if (!mounted) return;
    var granted = false;
    if (wants) granted = await ref.read(permissionServiceProvider).requestNotifications();
    await ref.read(settingsProvider.notifier).setNotifications(optIn: wants && granted);
  }

  Future<void> _share(DayDetail detail) async {
    await ref.read(shareServiceProvider).shareDayCard(context, detail);
  }

  Future<void> _done() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _maybeAskNotifications();
    } finally {
      _leaving = false;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SummaryStrings.of(context);
    final detail = ref.watch(dayDetailProvider(widget.dayId));
    final bests = ref.watch(personalBestsProvider).asData?.value;
    final days = ref.watch(daysListProvider).asData?.value;

    return Scaffold(
      backgroundColor: c.bg,
      body: detail.when(
        loading: () => const SummarySkeleton(),
        error: (e, _) => Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.pad),
                  child: Text(s.loadFailed, style: AppText.bodyText(c.textSecondary), textAlign: TextAlign.center),
                ),
              ),
            ),
            BottomDock(
              child: PrimaryButton(label: s.done, onPressed: _done),
            ),
          ],
        ),
        data: (d) {
          final pbs = _personalBests(d.day.id, bests);
          _onFirstData(isPb: pbs.isNotEmpty);
          return _Body(
            detail: d,
            controller: _ctrl,
            steps: _steps,
            pbs: pbs,
            newMedals: ref.watch(achievementsProvider).newMedalIds,
            isFirstDay: days != null && days.length <= 1,
            onShare: () => _share(d),
            onDone: _done,
          );
        },
      ),
    );
  }

  /// Which records this day holds right now.
  List<Pb> _personalBests(String dayId, PersonalBests? b) {
    if (b == null) return const [];
    return [
      if (b.topSpeedDayId == dayId && b.topSpeedMs != null) Pb.topSpeed,
      if (b.biggestDayId == dayId && b.biggestDayDropM != null) Pb.biggestDay,
      if (b.longestRunDayId == dayId && b.longestRunDropM != null) Pb.longestRun,
    ];
  }
}

/// The three records a single day can hold.
enum Pb { topSpeed, biggestDay, longestRun }

class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.controller,
    required this.steps,
    required this.pbs,
    required this.newMedals,
    required this.isFirstDay,
    required this.onShare,
    required this.onDone,
  });

  final DayDetail detail;
  final AnimationController controller;
  final int steps;
  final List<Pb> pbs;

  /// Medal ids earned by this (most recent) day — docs/GAMIFICATION.md §5.
  final List<String> newMedals;
  final bool isFirstDay;
  final VoidCallback onShare;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = SummaryStrings.of(context);
    final st = detail.day.stats;
    final locale = l.code;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              RouteBlock(
                detail: detail,
                title: s.title,
                date: Fmt.dateLong(detail.day.startedAt, locale: locale),
                resort: detail.day.resortName,
                noTrackLabel: s.noTrack,
              ),
              const SizedBox(height: 28),
              _Gutter(
                child: CountUpNumber(
                  animation: countUpStep(controller, 0, steps),
                  value: st.dropM,
                  format: (v) => Fmt.metres(v, locale: locale),
                  unit: s.unitHm,
                  label: s.vertical,
                  size: 92,
                  color: AppColors.of(context).accent,
                ),
              ),
              // 'Platz 14 in Kitzbühel · Saison' (SOC-LIVE-DUEL) — a line,
              // never a card; absent while offline or not ranked.
              _Gutter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: RankTeaser(seasonKey: seasonKeyFromMs(detail.day.startedAt), resortId: detail.day.resortId, resortName: detail.day.resortName),
                ),
              ),
              const SizedBox(height: 20),
              _Gutter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CountUpNumber(
                        animation: countUpStep(controller, 1, steps),
                        value: st.runCount.toDouble(),
                        format: (v) => '${v.round()}',
                        label: s.runs,
                        size: 40,
                      ),
                    ),
                    Expanded(
                      child: CountUpNumber(
                        animation: countUpStep(controller, 2, steps),
                        value: st.maxSpeedMs,
                        format: (v) => Fmt.kmh(v, locale: locale),
                        unit: s.unitKmh,
                        label: s.topSpeed,
                        size: 40,
                      ),
                    ),
                    Expanded(
                      child: CountUpNumber(
                        animation: countUpStep(controller, 3, steps),
                        value: st.skiDistanceM,
                        format: (v) => Fmt.km(v, locale: locale),
                        unit: s.unitKm,
                        label: s.skiKm,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
              if (pbs.isNotEmpty) ...[const SizedBox(height: 24), _Gutter(child: RecordCard(pbs: pbs))],
              if (newMedals.isNotEmpty) ...[
                const SizedBox(height: 16),
                // With a record on screen the medals step back to wash cards:
                // exactly one solid champagne moment per Tagesbilanz.
                _Gutter(
                  child: NewMedalsBanner(ids: newMedals, solid: pbs.isEmpty),
                ),
              ],
              // The duel of this day, once the user was in one (SOC-LIVE-DUEL).
              _DuelSection(detail: detail),
              const SizedBox(height: 24),
              _Gutter(child: _BestRunCard(detail: detail)),
              const SizedBox(height: 20),
              _Gutter(child: _TimeCard(stats: st)),
              const SizedBox(height: 24),
              _Gutter(
                child: _MascotBlock(
                  line: mascotLineFor(
                    day: detail.day,
                    s: s,
                    isFirstDay: isFirstDay,
                    isPb: pbs.isNotEmpty,
                    dropMFormatted: Fmt.metres(st.dropM, locale: locale),
                  ),
                  celebrate: isFirstDay || pbs.isNotEmpty,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        BottomDock(
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton(label: s.share, glyph: Glyph.share, onPressed: onShare),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(label: s.done, onPressed: onDone),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Result card of the Tagesduell this day was part of — nothing while the
/// user had none, is signed out or the backend is unreachable.
class _DuelSection extends ConsumerWidget {
  const _DuelSection({required this.detail});
  final DayDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duel = ref.watch(dayDuelProvider(detail.day.startedAt)).asData?.value;
    if (duel == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: _Gutter(
        child: DuelResultCard(duel: duel, ownUserId: ref.watch(socialUserIdProvider), resortName: detail.day.resortName),
      ),
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
    child: child,
  );
}

/// The one real moment: a solid champagne card with ink text (docs/DESIGN.md §5).
class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.pbs});
  final List<Pb> pbs;

  static String lineFor(SummaryStrings s, List<Pb> pbs) {
    if (pbs.length == 1) {
      return switch (pbs.first) {
        Pb.topSpeed => s.recordFastestDay,
        Pb.biggestDay => s.recordBiggestDay,
        Pb.longestRun => s.recordLongestRun,
      };
    }
    return [
      for (final p in pbs)
        switch (p) {
          Pb.topSpeed => s.topSpeed,
          Pb.biggestDay => s.biggestDay,
          Pb.longestRun => s.longestRun,
        },
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SummaryStrings.of(context);
    return SizedBox(
      height: 76,
      width: double.infinity,
      child: SurfaceCard(
        fill: c.accent,
        border: c.accent,
        radius: Tokens.r20,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        // SurfaceCard lays its child out loosely (Stack): without the Align
        // the row hugs the top of the 76 pt card.
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              GlyphIcon(Glyph.crest, size: 22, color: c.onAccent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.record.overline, style: AppText.label(c.onAccent.withValues(alpha: 0.72))),
                    const SizedBox(height: 5),
                    Text(lineFor(s, pbs), style: AppText.title(c.onAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Beste Abfahrt: title line plus a 3-up metric strip.
class _BestRunCard extends StatelessWidget {
  const _BestRunCard({required this.detail});
  final DayDetail detail;

  Segment? get _best {
    final runs = detail.runs.toList();
    if (runs.isEmpty) return null;
    final byId = detail.day.stats.longestRunSegmentId;
    for (final r in runs) {
      if (r.id == byId) return r;
    }
    runs.sort((a, b) => b.dropM.compareTo(a.dropM));
    return runs.first;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = SummaryStrings.of(context);
    final run = _best;
    return AppCard(
      header: s.bestRun,
      child: run == null
          ? Text(s.noRuns, style: AppText.bodyText(c.textSecondary, size: 15))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.bestRunTitle(
                    number: run.runNumber ?? 1,
                    clock: Fmt.timeOfDay(run.startTs, locale: l.code),
                  ),
                  style: AppText.title(c.textPrimary),
                ),
                const SizedBox(height: 14),
                MetricStrip(
                  size: 22,
                  items: [
                    (Fmt.metres(run.dropM, locale: l.code), s.unitHm),
                    (Fmt.km(run.distanceM, locale: l.code), s.unitKm),
                    (Fmt.kmh(run.maxSpeedMs, locale: l.code), s.unitKmh),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Ski · Lift · Pause with the day's total on the header line ('38 min',
/// '5h 12' — never a running clock).
class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.stats});
  final DayStats stats;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = SummaryStrings.of(context);
    final seg = timeLegendSegments(stats);
    return AppCard(
      header: s.timeOnSnow,
      trailing: Text(Fmt.durationCompact(stats.elapsedMs, locale: l.code), style: AppText.numXs(c.textPrimary)),
      child: StackedTimeBar(skiMs: seg.skiMs, liftMs: seg.liftMs, pauseMs: seg.pauseMs, signalLossMs: seg.signalLossMs, labels: s.timeBarLabels),
    );
  }
}

/// Leo plus one rule-based sentence — no floating circle (docs/DESIGN.md §5).
class _MascotBlock extends StatelessWidget {
  const _MascotBlock({required this.line, required this.celebrate});
  final String line;
  final bool celebrate;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.fromLTRB(12, 14, 18, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Rider(pose: celebrate ? 'celebrate' : 'lean', size: 84),
        const SizedBox(width: 6),
        Expanded(child: RiderLine(line)),
      ],
    ),
  );
}
