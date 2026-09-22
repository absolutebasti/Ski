import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import 'social_controls.dart';
import 'social_models.dart';
import 'social_strings.dart';

/// 2nd · 1st · 3rd — avatars 48/64/48, champagne ring on the winner
/// (docs/DESIGN.md §5 "Rangliste" 3.).
class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({super.key, required this.entries, required this.metric, this.ownUserId});

  /// Up to three entries in rank order.
  final List<LeaderboardEntry> entries;
  final SocialMetric metric;
  final String? ownUserId;

  @override
  Widget build(BuildContext context) {
    final order = <LeaderboardEntry?>[
      entries.length > 1 ? entries[1] : null,
      entries.isNotEmpty ? entries[0] : null,
      entries.length > 2 ? entries[2] : null,
    ];
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, e) in order.indexed)
            Expanded(child: e == null ? const SizedBox(height: 120) : _PodiumColumn(entry: e, metric: metric, first: i == 1, own: e.userId == ownUserId)),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({required this.entry, required this.metric, required this.first, required this.own});
  final LeaderboardEntry entry;
  final SocialMetric metric;
  final bool first;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final (value, unit) = s.value(metric, entry.value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarCircle(name: entry.displayName, size: first ? 64 : 48, ring: first, accent: first),
        const SizedBox(height: 10),
        _RankPlate(rank: entry.rank, first: first),
        const SizedBox(height: 10),
        Text(
          own ? s.you : entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppText.caption(own ? c.textPrimary : c.textSecondary),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.numS(first ? c.accent : c.textPrimary))),
            if (unit != null) ...[const SizedBox(width: 4), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
          ],
        ),
      ],
    );
  }
}

class _RankPlate extends StatelessWidget {
  const _RankPlate({required this.rank, required this.first});
  final int rank;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: first ? c.accent : c.surfaceRaised,
        shape: Squircle.border(Tokens.r10, side: first ? Colors.transparent : c.hairline, width: c.hairlineWidth),
      ),
      child: Text('$rank', style: AppText.numXs(first ? c.onAccent : c.textSecondary).copyWith(fontSize: 13)),
    );
  }
}

/// The hairline-separated rows below the podium (h 64).
class LeaderboardRows extends StatelessWidget {
  const LeaderboardRows({super.key, required this.entries, required this.metric, this.ownUserId});

  final List<LeaderboardEntry> entries;
  final SocialMetric metric;
  final String? ownUserId;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) const Hairline(inset: 18),
            LeaderboardRow(entry: e, metric: metric, own: e.userId == ownUserId),
          ],
        ],
      ),
    );
  }
}

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({super.key, required this.entry, required this.metric, this.own = false});

  final LeaderboardEntry entry;
  final SocialMetric metric;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final (value, unit) = s.value(metric, entry.value);
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text('${entry.rank}', style: AppText.numS(c.textTertiary).copyWith(fontSize: 18))),
            AvatarCircle(name: entry.displayName, size: 36, accent: own),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyText(c.textPrimary, size: 16, weight: own ? FontWeight.w700 : FontWeight.w500)),
                  if (own) Text(s.you, style: AppText.caption(c.accent, size: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppText.numS(c.accent)),
                if (unit != null) ...[const SizedBox(width: 4), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 'Du · Platz 14 · 12.480 hm' — L2 glass strip pinned above the tab bar.
class OwnRankStrip extends StatelessWidget {
  const OwnRankStrip({super.key, required this.rank, required this.metric, required this.name, this.bottomPadding = 0});

  final MyRank rank;
  final SocialMetric metric;
  final String name;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final (value, unit) = s.value(metric, rank.value);
    return Semantics(
      label: s.ownRow(rank.rank, metric, rank.value),
      container: true,
      child: GlassLayer(
        topHairline: true,
        child: ColoredBox(
          color: c.accentWash,
          child: Padding(
            padding: EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 12 + bottomPadding),
            child: Row(
              children: [
                AvatarCircle(name: name, size: 32, accent: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${s.you} · ${s.rank} ${rank.rank}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong(c.textPrimary, size: 15),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: AppText.numS(c.accent)),
                    if (unit != null) ...[const SizedBox(width: 4), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
