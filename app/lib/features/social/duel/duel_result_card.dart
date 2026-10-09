import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import '../../share/share_card_data.dart';
import '../../share/share_service.dart';
import '../social_controls.dart';
import '../social_models.dart';
import '../social_strings.dart';
import 'duel_models.dart';
import 'duel_strings.dart';
import '../rider_name.dart';

/// Final board of a Tagesduell for the Tagesbilanz and the history sheet:
/// the result line ('Gewonnen' / 'Platz 2 von 3'), every member with their
/// Höhenmeter, the winner ringed in champagne, 'Teilen' → the SHARE-CARDS
/// duel card. Plain card tone: the Tagesbilanz allows one solid champagne
/// moment and that one belongs to the record.
class DuelResultCard extends ConsumerWidget {
  const DuelResultCard({super.key, required this.duel, this.ownUserId, this.onShare, this.resortName});

  final DuelSummary duel;
  final String? ownUserId;

  /// Replaces the default share (tests); null = `ShareService.shareCard`.
  final VoidCallback? onShare;

  /// Shown on the share card; null = the group's resort is unknown.
  final String? resortName;

  /// The share payload: rows by vertical, own row marked.
  DuelCardData shareData() => DuelCardData(
        day: duel.day.millisecondsSinceEpoch,
        name: duel.group.name,
        resortName: resortName,
        rows: [
          for (final m in duel.board)
            DuelCardRow(displayName: m.displayName, dropM: m.dropM, runCount: m.runCount, maxSpeedMs: m.maxSpeedMs, isMe: m.userId == ownUserId),
        ],
      );

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final custom = onShare;
    if (custom != null) return custom();
    await ref.read(shareServiceProvider).shareCard(context, ShareCardKind.duel, shareData());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final ds = DuelStrings.of(context);
    final l = AppLocale.of(context).code;
    final winner = duel.winner;
    final place = duel.placeOf(ownUserId);
    final headline = duel.anyLive ? ds.pending : ds.resultLine(place, duel.participants);
    return AppCard(
      header: ds.result,
      trailing: Text(Fmt.dateShort(duel.day.millisecondsSinceEpoch, locale: l), style: AppText.caption(c.textTertiary, size: 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(headline, style: AppText.title(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          for (final (i, m) in duel.board.indexed) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Hairline()),
            _ResultRow(
              member: m,
              place: i + 1,
              winner: winner != null && m.userId == winner.userId,
              own: m.userId == ownUserId,
            ),
          ],
          if (duel.board.isEmpty) Text(s.duelWaiting, style: AppText.bodyText(c.textSecondary, size: 15)),
          const SizedBox(height: 14),
          SecondaryButton(label: ds.share, glyph: Glyph.share, height: Tokens.buttonMd, onPressed: () => _share(context, ref)),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.member, required this.place, required this.winner, required this.own});
  final DuelMember member;
  final int place;
  final bool winner;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final l = AppLocale.of(context).code;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(width: 18, child: Text('$place', style: AppText.numXs(winner ? c.accent : c.textTertiary))),
          const SizedBox(width: 6),
          AvatarCircle(name: member.displayName, size: 32, ring: winner, accent: winner, avatarUrl: member.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(own ? s.you : riderName(context, member.displayName), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyText(c.textPrimary, size: 16, weight: own ? FontWeight.w700 : FontWeight.w500)),
                Text(
                  '${member.runCount} ${s.metric(SocialMetric.runCount)} · ${Fmt.kmh(member.maxSpeedMs, locale: l)} km/h',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(c.textSecondary, size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: Tokens.cardGap),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(Fmt.metres(member.dropM, locale: l), style: AppText.numS(winner ? c.accent : c.textPrimary)),
              const SizedBox(width: 4),
              Text(s.unitHm, style: AppText.unit(c.textTertiary, size: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
