import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../leaderboard_providers.dart';
import '../social_models.dart';
import 'duel_strings.dart';

/// One line on the Tagesbilanz: 'Platz 14 in Kitzbühel · Saison' from the
/// RPC `my_rank` for the season board of the day's resort (the global board
/// when the day has none). Hidden while loading, offline, signed out, not
/// opted in or not ranked — the Tagesbilanz never waits for the network.
class RankTeaser extends ConsumerWidget {
  const RankTeaser({super.key, required this.seasonKey, this.resortId, this.resortName, this.metric = SocialMetric.dropM});

  /// 'YYYY/YY' of the day.
  final String seasonKey;
  final String? resortId;

  /// Shown in the line; null = 'Platz 14 · Saison'.
  final String? resortName;
  final SocialMetric metric;

  LeaderboardQuery get query => LeaderboardQuery(seasonKey: seasonKey, resortId: resortId, metric: metric);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final ds = DuelStrings.of(context);
    final rank = ref.watch(myRankProvider(query)).asData?.value;
    if (rank == null || rank.rank <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlyphIcon(Glyph.podium, size: 14, color: c.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            ds.rankTeaser(rank.rank, resortId == null ? null : resortName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption(c.textSecondary),
          ),
        ),
      ],
    );
  }
}
