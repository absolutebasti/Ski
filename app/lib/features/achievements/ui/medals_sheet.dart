import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import '../../share/share_card_data.dart';
import '../../share/share_service.dart';
import '../../share/share_strings.dart';
import '../achievement_models.dart';
import '../achievements_providers.dart';
import '../achievements_strings.dart';
import 'level_ring.dart';

/// Medaillen sheet: 96 pt level ring + next-level line + points formula, then
/// one section per metric with four tier tiles. Locked tiles sit at 45 % with
/// a progress rule.
class MedalsSheet {
  const MedalsSheet._();

  /// Opacity of a locked tile (tests look for it).
  static const double lockedOpacity = 0.45;

  static Future<void> show(BuildContext context) {
    // Guarded: no platform channel in tests, no crash if the device refuses.
    try {
      unawaited(HapticFeedback.selectionClick().catchError((_) {}));
    } catch (_) {
      // No haptics available (tests, simulator): ignore.
    }
    return AppSheet.show<void>(context, expand: true, title: AchievementsStrings.of(context).medalsTitle, builder: (_) => const MedalsSheetBody());
  }
}

/// Body of the sheet; exposed so the lead can embed it in a page if needed.
class MedalsSheetBody extends ConsumerWidget {
  const MedalsSheetBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(achievementsProvider);
    final c = AppColors.of(context);
    final s = AchievementsStrings.of(context);
    final byMetric = <AchievementMetric, List<MedalState>>{};
    for (final m in a.medals) {
      byMetric.putIfAbsent(m.def.metric, () => []).add(m);
    }
    final nextAt = a.level.nextAtM;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 16, 0, MediaQuery.paddingOf(context).bottom + Tokens.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
            child: Row(
              children: [
                LevelRing(level: a.level, size: 96),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.level} ${a.level.index}'.overline, style: AppText.label(c.textTertiary)),
                      const SizedBox(height: 6),
                      Text(s.levelTitle(a.level), style: AppText.headline(c.textPrimary)),
                      const SizedBox(height: 6),
                      Text(
                        nextAt == null ? s.topLevel : s.nextLevel((nextAt - a.level.distanceM).clamp(0, double.infinity), a.level.index + 1),
                        style: AppText.caption(c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
            child: Text(s.formula, style: AppText.caption(c.textTertiary, size: 12)),
          ),
          for (final metric in AchievementMetric.values)
            if (byMetric[metric] case final medals?) ...[
              SectionLabel(
                s.metric(metric),
                padding: const EdgeInsets.fromLTRB(Tokens.pad, Tokens.sectionGap, Tokens.pad, 10),
                trailing: Text('${medals.where((m) => m.earned).length} / ${medals.length}', style: AppText.numXs(c.textSecondary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
                child: _TileRow(medals: medals),
              ),
            ],
        ],
      ),
    );
  }
}

/// Four tiles per row; a metric with fewer tiers keeps the column widths.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.medals});
  final List<MedalState> medals;

  @override
  Widget build(BuildContext context) {
    final rows = <List<MedalState>>[];
    for (var i = 0; i < medals.length; i += 4) {
      rows.add(medals.sublist(i, (i + 4).clamp(0, medals.length)));
    }
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: i < row.length ? MedalTile(state: row[i]) : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One medal: tier ring, one-line title, threshold + unit and a 14 pt footer
/// slot holding either the earned date or the progress rule. Fixed height so
/// every tile in a row lines up. Long-pressing an earned tile shares the
/// medal card (`ShareService.shareCard(ShareCardKind.medal)`).
class MedalTile extends ConsumerWidget {
  const MedalTile({super.key, required this.state});
  final MedalState state;

  /// Outer height of every tile.
  static const double height = 132;

  /// Height of the footer slot (date or progress rule).
  static const double footerHeight = 14;

  /// Title size: fixed, so the four titles of a row never differ.
  static const double titleSize = 11.5;

  /// Title style (Inter 600 at [titleSize]).
  static TextStyle titleStyle(Color color) => AppText.caption(color, size: titleSize).copyWith(fontWeight: FontWeight.w600, height: 1.2);

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final earnedAt = state.earnedAt;
    if (earnedAt == null) return;
    try {
      unawaited(HapticFeedback.mediumImpact().catchError((_) {}));
    } catch (_) {
      // No haptics available (tests, simulator): ignore.
    }
    try {
      await ref.read(shareServiceProvider).shareCard(context, ShareCardKind.medal, MedalCardData(def: state.def, earnedAt: earnedAt));
    } catch (_) {
      // Share sheet dismissed or render failed: nothing to recover.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AchievementsStrings.of(context);
    final def = state.def;
    final (value, unit) = s.threshold(def);
    final title = s.medalTitle(def);
    final thresholdLine = unit == null ? value : '$value $unit';
    final earnedAt = state.earnedAt;
    return Semantics(
      key: ValueKey('medal-${def.id}'),
      label: s.medalSemantics(state),
      hint: state.earned ? ShareStrings.of(context).shareMedalHint : null,
      excludeSemantics: true,
      child: Pressable(
        onLongPress: state.earned ? () => _share(context, ref) : null,
        child: SizedBox(
          height: height,
          child: Opacity(
            opacity: state.earned ? 1 : MedalsSheet.lockedOpacity,
            child: SurfaceCard(
              radius: Tokens.r14,
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
              child: Column(
                children: [
                  TierRing(tier: def.tier, earned: state.earned, size: 34),
                  const SizedBox(height: 8),
                  // Fixed 11.5 pt: every title in a row is the same size, a
                  // long one ellipsises instead of shrinking.
                  SizedBox(
                    height: 16,
                    width: double.infinity,
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: titleStyle(c.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Threshold + unit, unless it would only repeat the title.
                  SizedBox(
                    height: 16,
                    child: thresholdLine == title
                        ? null
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(value, style: AppText.numXs(c.textPrimary)),
                                if (unit != null) ...[const SizedBox(width: 3), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
                              ],
                            ),
                          ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: footerHeight,
                    width: double.infinity,
                    child: earnedAt != null
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              Fmt.dateShort(earnedAt, locale: l.code),
                              maxLines: 1,
                              softWrap: false,
                              style: AppText.caption(c.textSecondary, size: 11),
                            ),
                          )
                        : Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1.5),
                              child: SizedBox(
                                height: 3,
                                width: double.infinity,
                                child: Stack(
                                  children: [
                                    Container(color: c.hairlineStrong),
                                    FractionallySizedBox(
                                      widthFactor: state.progress.clamp(0.0, 1.0),
                                      child: Container(color: c.accent),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
