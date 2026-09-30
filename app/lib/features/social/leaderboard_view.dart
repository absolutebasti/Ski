import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import 'country_card.dart';
import 'rider/rider_sheet.dart';
import 'rider_name.dart';
import 'social_controls.dart';
import 'social_models.dart';
import 'social_strings.dart';

/// What happens when a rider on the board is tapped; the default opens the
/// [RiderSheet] for that user id.
typedef RiderTap = void Function(BuildContext context, String userId);

void _openRider(BuildContext context, String userId) => RiderSheet.show(context, userId);

/// 2nd · 1st · 3rd — avatars 48/64/48, champagne ring on the winner and on
/// the winner's team flag (docs/DESIGN.md §5 "Rangliste" 3.). Every column
/// opens the rider's profile.
class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({super.key, required this.entries, required this.metric, this.ownUserId, this.onRider = _openRider});

  /// Up to three entries in rank order.
  final List<LeaderboardEntry> entries;
  final SocialMetric metric;
  final String? ownUserId;
  final RiderTap onRider;

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
            Expanded(
              child: e == null
                  ? const SizedBox(height: 120)
                  : _PodiumColumn(entry: e, metric: metric, first: i == 1, own: e.userId == ownUserId, onTap: () => onRider(context, e.userId)),
            ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({required this.entry, required this.metric, required this.first, required this.own, required this.onTap});
  final LeaderboardEntry entry;
  final SocialMetric metric;
  final bool first;
  final bool own;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final (value, unit) = s.value(metric, entry.value);
    final flag = entry.countryCode;
    final name = riderName(context, entry.displayName);
    return Semantics(
      label: s.rowLabel(entry.rank, own ? s.you : name, metric, entry.value),
      button: true,
      container: true,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarCircle(name: name, avatarUrl: entry.avatarUrl, size: first ? 64 : 48, ring: first, accent: first),
            const SizedBox(height: 10),
            _RankPlate(rank: entry.rank, first: first),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    own ? s.you : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppText.caption(own ? c.textPrimary : c.textSecondary),
                  ),
                ),
                if (flag != null) ...[const SizedBox(width: 4), CountryFlag(countryCode: flag, size: 16, ring: first)],
              ],
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
        ),
      ),
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

/// The hairline-separated rows below the podium (h 64). [leaderValue] is the
/// value of rank 1 (for the delta caption); defaults to the first row's.
class LeaderboardRows extends StatelessWidget {
  const LeaderboardRows({super.key, required this.entries, required this.metric, this.ownUserId, this.leaderValue, this.onRider = _openRider});

  final List<LeaderboardEntry> entries;
  final SocialMetric metric;
  final String? ownUserId;
  final double? leaderValue;
  final RiderTap onRider;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final lead = leaderValue ?? entries.first.value;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) const Hairline(inset: 18),
            LeaderboardRow(entry: e, metric: metric, own: e.userId == ownUserId, leaderValue: lead, onTap: () => onRider(context, e.userId)),
          ],
        ],
      ),
    );
  }
}

/// rank · avatar · name + flag, caption 'zuletzt Sa. · 7 Tage' · value + unit,
/// delta to the leader in tertiary. Tap opens the rider.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({super.key, required this.entry, required this.metric, this.own = false, this.leaderValue, this.onTap});

  final LeaderboardEntry entry;
  final SocialMetric metric;
  final bool own;

  /// Value of rank 1; null hides the delta.
  final double? leaderValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final (value, unit) = s.value(metric, entry.value);
    final caption = own ? s.you : s.rowCaption(entry.lastDayMs, entry.dayCount);
    final lead = leaderValue;
    final delta = lead == null ? '' : s.delta(metric, lead - entry.value);
    final flag = entry.countryCode;
    final name = riderName(context, entry.displayName);
    return Semantics(
      label: s.rowLabel(entry.rank, name, metric, entry.value),
      button: onTap != null,
      container: true,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(width: 32, child: Text('${entry.rank}', style: AppText.numS(c.textTertiary).copyWith(fontSize: 18))),
                AvatarCircle(name: name, avatarUrl: entry.avatarUrl, size: 36, accent: own),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyText(c.textPrimary, size: 16, weight: own ? FontWeight.w700 : FontWeight.w500),
                            ),
                          ),
                          if (flag != null) ...[const SizedBox(width: 6), CountryFlag(countryCode: flag, size: 16)],
                        ],
                      ),
                      if (caption.isNotEmpty) Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(own ? c.accent : c.textTertiary, size: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(value, style: AppText.numS(c.accent)),
                        if (unit != null) ...[const SizedBox(width: 4), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
                      ],
                    ),
                    if (delta.isNotEmpty) Text(delta, style: AppText.caption(c.textTertiary, size: 11)),
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

/// 'Du · Platz 14 von 250 · 12.480 hm' — L2 glass strip pinned above the tab
/// bar. [rank] null = 'Du bist noch nicht gewertet'. [onJump] shows 'Zu mir
/// springen' (the own rank is outside the fetched window), [onTop] 'Nach oben'.
/// [onShare] adds the share glyph on the right (rank card) — only with a rank.
class OwnRankStrip extends StatelessWidget {
  const OwnRankStrip({
    super.key,
    required this.rank,
    required this.metric,
    required this.name,
    this.avatarUrl,
    this.bottomPadding = 0,
    this.onJump,
    this.onTop,
    this.onShare,
  });

  final MyRank? rank;
  final SocialMetric metric;
  final String name;
  final String? avatarUrl;
  final double bottomPadding;
  final VoidCallback? onJump;
  final VoidCallback? onTop;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final r = rank;
    final (value, unit) = r == null ? ('', null) : s.value(metric, r.value);
    final action = onJump != null ? (s.jumpToMe, onJump) : (onTop != null ? (s.backToTop, onTop) : null);
    return Semantics(
      label: r == null ? s.notRankedYet : s.ownRow(r.rank, metric, r.value, total: r.total),
      container: true,
      child: GlassLayer(
        topHairline: true,
        child: ColoredBox(
          color: c.accentWash,
          child: Padding(
            padding: EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 12 + bottomPadding),
            child: Row(
              children: [
                AvatarCircle(name: riderName(context, name), avatarUrl: avatarUrl, size: 32, accent: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r == null ? s.notRankedYet : '${s.you} · ${s.rankOf(r.rank, r.total)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong(c.textPrimary, size: 15),
                      ),
                      if (action != null)
                        HitSlop(
                          child: Pressable(
                            onTap: action.$2,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(action.$1, style: AppText.caption(c.accent, size: 12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (r != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(value, style: AppText.numS(c.accent)),
                      if (unit != null) ...[const SizedBox(width: 4), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
                    ],
                  ),
                if (r != null && onShare != null) ...[
                  const SizedBox(width: 10),
                  HeaderButton(key: const ValueKey('own-rank-share'), glyph: Glyph.share, size: 32, tooltip: s.shareRank, onTap: onShare),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
