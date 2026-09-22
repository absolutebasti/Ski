import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/db/providers.dart';
import 'day_actions.dart';
import 'day_card.dart';
import 'days_strings.dart';
import 'season_groups.dart';

/// Tab 1 — season header, personal bests and every finished day, newest first
/// (docs/PLAN.md §3 row "Tage"). Older seasons sit behind a collapsed header.
class TageScreen extends ConsumerStatefulWidget {
  const TageScreen({super.key});

  @override
  ConsumerState<TageScreen> createState() => _TageScreenState();
}

class _TageScreenState extends ConsumerState<TageScreen> {
  /// Season keys the user opened by hand; the newest season is always open.
  final _expanded = <String>{};

  Future<void> _onLongPress(DaySummary day) async {
    final action = await showDayMenu(context);
    if (action == null || !mounted) return;
    switch (action) {
      case DayMenuAction.share:
        await shareDayCardById(context, ref, day.id);
      case DayMenuAction.delete:
        final ok = await confirmDeleteDay(context);
        if (!ok || !mounted) return;
        await deleteDayById(ref, day.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = DaysStrings.of(context);
    final days = ref.watch(daysListProvider);
    final totals = ref.watch(seasonTotalsProvider).asData?.value ?? const <SeasonTotals>[];
    final bests = ref.watch(personalBestsProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.pad),
            child: Text(s.loadFailed, style: AppText.bodyText(c.textSecondary), textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: EmptyState(line: s.emptyLine));
          }
          final groups = groupBySeason(list);
          return ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 32),
            children: [
              _SeasonHeader(totals: totalsFor(totals, groups.first.seasonKey), seasonKey: groups.first.seasonKey),
              if (bests != null) ...[const SizedBox(height: 12), _PbChips(bests: bests)],
              const SizedBox(height: 20),
              for (final g in groups.first.days) DayCard(day: g, onTap: () => AppNav.openDay(context, g.id), onLongPress: () => _onLongPress(g)),
              for (final group in groups.skip(1)) ...[
                const SizedBox(height: 4),
                _OlderSeason(
                  group: group,
                  totals: totalsFor(totals, group.seasonKey),
                  expanded: _expanded.contains(group.seasonKey),
                  onToggle: () => setState(() =>
                      _expanded.contains(group.seasonKey) ? _expanded.remove(group.seasonKey) : _expanded.add(group.seasonKey)),
                  onOpen: (d) => AppNav.openDay(context, d.id),
                  onLongPress: _onLongPress,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({required this.totals, required this.seasonKey});
  final SeasonTotals? totals;
  final String seasonKey;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final t = totals ?? SeasonTotals(seasonKey: seasonKey);
    return Text(
      s.seasonLine(season: t.seasonKey, days: t.dayCount, runs: t.runCount, dropM: Fmt.metres(t.dropM, locale: l.code)),
      style: AppText.title(c.textPrimary, size: 18),
    );
  }
}

class _PbChips extends StatelessWidget {
  const _PbChips({required this.bests});
  final PersonalBests bests;

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final chips = <Widget>[
      if (bests.topSpeedMs != null)
        StateChip(text: '${s.topSpeed} ${Fmt.kmh(bests.topSpeedMs!, locale: l.code)} ${s.unitKmh}', tone: ChipTone.accent, icon: Icons.speed_rounded),
      if (bests.biggestDayDropM != null)
        StateChip(text: '${s.biggestDay} ${Fmt.metres(bests.biggestDayDropM!, locale: l.code)} ${s.unitHm}', tone: ChipTone.accent, icon: Icons.terrain_rounded),
      if (bests.longestRunDropM != null)
        StateChip(
            text: '${s.longestRun} ${Fmt.metres(bests.longestRunDropM!, locale: l.code)} ${s.unitHm}',
            tone: ChipTone.accent,
            icon: Icons.downhill_skiing_rounded),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _OlderSeason extends StatelessWidget {
  const _OlderSeason({
    required this.group,
    required this.totals,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onLongPress,
  });

  final SeasonGroup group;
  final SeasonTotals? totals;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(DaySummary) onOpen;
  final void Function(DaySummary) onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final t = totals ?? SeasonTotals(seasonKey: group.seasonKey, dayCount: group.days.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(Tokens.radius),
          onTap: onToggle,
          child: SizedBox(
            height: Tokens.minTarget,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.seasonLine(season: t.seasonKey, days: t.dayCount, runs: t.runCount, dropM: Fmt.metres(t.dropM, locale: l.code)),
                    style: AppText.label(c.textSecondary, size: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.textSecondary, size: 22),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final d in group.days) DayCard(day: d, onTap: () => onOpen(d), onLongPress: () => onLongPress(d)),
      ],
    );
  }
}
