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
import '../share/share_service.dart';
import 'count_up.dart';
import 'mascot_line.dart';
import 'notifications_sheet.dart';
import 'summary_strings.dart';

/// Full-screen route right after "Tag beenden" (docs/PLAN.md §3 row
/// "Tagesbilanz"): four numbers count up, then the day explains itself.
class TagesbilanzScreen extends ConsumerStatefulWidget {
  const TagesbilanzScreen({super.key, required this.dayId});
  final String dayId;

  @override
  ConsumerState<TagesbilanzScreen> createState() => _TagesbilanzScreenState();
}

class _TagesbilanzScreenState extends ConsumerState<TagesbilanzScreen> with SingleTickerProviderStateMixin {
  static const int _steps = 4;

  late final AnimationController _ctrl = AnimationController(vsync: this, duration: countUpTotal(_steps));
  bool _started = false;
  bool _hapticDone = false;
  bool _askedNotifications = false;

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
      unawaited(_maybeAskNotifications());
    });
  }

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

  void _done() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SummaryStrings.of(context);
    final detail = ref.watch(dayDetailProvider(widget.dayId));
    final bests = ref.watch(personalBestsProvider).asData?.value;
    final days = ref.watch(daysListProvider).asData?.value;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s.title), automaticallyImplyLeading: false),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.pad),
            child: Text(s.loadFailed, style: AppText.bodyText(c.textSecondary), textAlign: TextAlign.center),
          ),
        ),
        data: (d) {
          final pbs = _personalBests(d.day.id, bests);
          _onFirstData(isPb: pbs.isNotEmpty);
          return _Body(
            detail: d,
            controller: _ctrl,
            steps: _steps,
            pbs: pbs,
            isFirstDay: days != null && days.length <= 1,
            onShare: () => _share(d),
            onDone: _done,
          );
        },
      ),
    );
  }

  /// Which records this day holds right now.
  List<_Pb> _personalBests(String dayId, PersonalBests? b) {
    if (b == null) return const [];
    return [
      if (b.topSpeedDayId == dayId && b.topSpeedMs != null) _Pb.topSpeed,
      if (b.biggestDayId == dayId && b.biggestDayDropM != null) _Pb.biggestDay,
      if (b.longestRunDayId == dayId && b.longestRunDropM != null) _Pb.longestRun,
    ];
  }
}

enum _Pb { topSpeed, biggestDay, longestRun }

class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.controller,
    required this.steps,
    required this.pbs,
    required this.isFirstDay,
    required this.onShare,
    required this.onDone,
  });

  final DayDetail detail;
  final AnimationController controller;
  final int steps;
  final List<_Pb> pbs;
  final bool isFirstDay;
  final VoidCallback onShare;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = SummaryStrings.of(context);
    final st = detail.day.stats;
    final locale = l.code;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 16),
            children: [
              Text(
                '${Fmt.dateLong(detail.day.startedAt, locale: locale)}'
                '${detail.day.resortName == null ? '' : ' · ${detail.day.resortName}'}',
                style: AppText.bodyText(c.textSecondary, size: 15),
              ),
              const SizedBox(height: 16),
              CountUpNumber(
                animation: countUpStep(controller, 0, steps),
                value: st.dropM,
                format: (v) => Fmt.metres(v, locale: locale),
                unit: s.unitHm,
                label: s.vertical,
                size: 64,
              ),
              const SizedBox(height: 24),
              Row(
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
              const SizedBox(height: 28),
              StackedTimeBar(
                skiMs: st.skiMs,
                liftMs: st.liftMs,
                pauseMs: st.pauseMs,
                signalLossMs: st.signalLossMs,
                otherMs: st.otherMs,
                labels: s.timeBarLabels,
              ),
              const SizedBox(height: 24),
              _BestRunCard(detail: detail),
              if (pbs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final p in pbs) _PbChip(pb: p)]),
              ],
              const SizedBox(height: 28),
              EmptyState(
                line: mascotLineFor(
                  day: detail.day,
                  s: s,
                  isFirstDay: isFirstDay,
                  isPb: pbs.isNotEmpty,
                  dropMFormatted: Fmt.metres(st.dropM, locale: locale),
                ),
                size: 96,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, Tokens.pad),
          child: Row(
            children: [
              Expanded(child: SecondaryButton(label: s.share, icon: Icons.ios_share_rounded, onPressed: onShare)),
              const SizedBox(width: 12),
              Expanded(child: PrimaryButton(label: s.done, onPressed: onDone)),
            ],
          ),
        ),
      ],
    );
  }
}

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.bestRun.toUpperCase(), style: AppText.label(c.textSecondary)),
          const SizedBox(height: 8),
          Text(
            run == null
                ? s.noRuns
                : s.bestRunLine(
                    number: run.runNumber ?? 1,
                    clock: Fmt.timeOfDay(run.startTs, locale: l.code),
                    dropM: Fmt.metres(run.dropM, locale: l.code),
                    km: Fmt.km(run.distanceM, locale: l.code),
                    kmh: Fmt.kmh(run.maxSpeedMs, locale: l.code),
                  ),
            style: AppText.bodyText(c.textPrimary, size: 16),
          ),
        ],
      ),
    );
  }
}

class _PbChip extends StatelessWidget {
  const _PbChip({required this.pb});
  final _Pb pb;

  @override
  Widget build(BuildContext context) {
    final s = SummaryStrings.of(context);
    final (label, icon) = switch (pb) {
      _Pb.topSpeed => (s.topSpeed, Icons.speed_rounded),
      _Pb.biggestDay => (s.biggestDay, Icons.landscape_rounded),
      _Pb.longestRun => (s.longestRun, Icons.timeline_rounded),
    };
    return StateChip(text: '${s.record} · $label', tone: ChipTone.accent, icon: icon);
  }
}
