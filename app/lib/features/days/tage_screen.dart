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
import '../today/season_card.dart';
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
      backgroundColor: Colors.transparent,
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
            return SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, 32),
                children: [
                  ScreenHeader(title: s.title, padding: const EdgeInsets.fromLTRB(0, 8, 0, 16)),
                  EmptyState(headline: s.emptyHeadline, line: s.emptyLine),
                ],
              ),
            );
          }
          final groups = groupBySeason(list);
          final first = totalsFor(totals, groups.first.seasonKey) ?? SeasonTotals(seasonKey: groups.first.seasonKey, dayCount: groups.first.days.length);
          final previous = groups.length > 1 ? totalsFor(totals, groups[1].seasonKey) : null;
          return SafeArea(
            bottom: false,
            child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, 120),
            children: [
              ScreenHeader(title: s.title, caption: '${s.seasonWord} ${groups.first.seasonKey}', padding: const EdgeInsets.fromLTRB(0, 8, 0, 16)),
              SeasonCard(totals: first, days: groups.first.days, previous: previous, compact: true),
              if (bests != null) ...[const SizedBox(height: Tokens.cardGap), _PbStrip(bests: bests)],
              SectionLabel(s.dayTitlePlural, padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10), trailing: _SeasonHeader(totals: first, seasonKey: groups.first.seasonKey)),
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
          ),
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
    final s = DaysStrings.of(context);
    final t = totals ?? SeasonTotals(seasonKey: seasonKey);
    return Text(
      '${s.dayCount(t.dayCount)} · ${s.runCount(t.runCount)}',
      style: AppText.numXs(c.textSecondary).copyWith(fontFamily: AppText.body, fontWeight: FontWeight.w600),
    );
  }
}

class _PbStrip extends StatelessWidget {
  const _PbStrip({required this.bests});
  final PersonalBests bests;

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final tiles = <Widget>[
      if (bests.topSpeedMs != null) PbTile(label: s.topSpeed, value: Fmt.kmh(bests.topSpeedMs!, locale: l.code), unit: s.unitKmh),
      if (bests.biggestDayDropM != null) PbTile(label: s.biggestDay, value: Fmt.metres(bests.biggestDayDropM!, locale: l.code), unit: s.unitHm),
      if (bests.longestRunDropM != null) PbTile(label: s.longestRun, value: Fmt.metres(bests.longestRunDropM!, locale: l.code), unit: s.unitHm),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Row(children: [for (final (i, w) in tiles.indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: w)]]);
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
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.cardGap),
          child: Pressable(
            onTap: onToggle,
            child: Container(
              height: Tokens.minTarget,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: ShapeDecoration(color: c.glassFill, shape: Squircle.border(Tokens.r20, side: c.glassStroke, width: c.hairlineWidth)),
              child: Row(
                children: [
                  Text('${s.seasonWord} ${t.seasonKey}'.overline, style: AppText.label(c.textTertiary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${s.dayCount(t.dayCount)} · ${Fmt.metres(t.dropM, locale: l.code)} ${s.unitHm}', style: AppText.numXs(c.textSecondary).copyWith(fontFamily: AppText.body, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(turns: expanded ? 0.25 : 0, duration: Tokens.medium, child: GlyphIcon(Glyph.chevronRight, size: 16, color: c.textTertiary)),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          for (final d in group.days) DayCard(day: d, onTap: () => onOpen(d), onLongPress: () => onLongPress(d)),
      ],
    );
  }
}
