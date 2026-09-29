import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../leaderboard_providers.dart';
import '../rider/rider_sheet.dart';
import '../social_api.dart';
import '../social_controls.dart';
import '../social_models.dart';
import '../social_strings.dart';
import 'challenge_api.dart';
import 'challenge_models.dart';
import 'challenge_providers.dart';
import 'challenge_strings.dart';

/// The board behind the Wochen-Challenge card (RPC `challenge_board`): every
/// participant ranked by the server-computed value, a check on the ones who
/// made it, own row highlighted. Rows open the [RiderSheet].
class ChallengeBoardSheet {
  const ChallengeBoardSheet._();

  static Future<void> show(BuildContext context, Challenge challenge, {DateTime? now}) => AppSheet.show<void>(
        context,
        expand: true,
        title: SocialStrings.of(context).challenge,
        builder: (_) => ChallengeBoardSheetBody(challenge: challenge, now: now),
      );
}

/// Body of the sheet; exposed for tests, use [ChallengeBoardSheet.show] in the app.
class ChallengeBoardSheetBody extends ConsumerStatefulWidget {
  const ChallengeBoardSheetBody({super.key, required this.challenge, this.now});

  final Challenge challenge;

  /// Injectable clock for the 'Noch 3 Tage' caption.
  final DateTime? now;

  @override
  ConsumerState<ChallengeBoardSheetBody> createState() => _ChallengeBoardSheetBodyState();
}

class _ChallengeBoardSheetBodyState extends ConsumerState<ChallengeBoardSheetBody> {
  bool _busy = false;

  void _retry() => ref.invalidate(challengeBoardProvider(widget.challenge.id));

  Future<void> _leave() async {
    final api = ref.read(challengeApiProvider);
    final s = SocialStrings.of(context);
    final cs = ChallengeStrings.of(context);
    if (api == null) {
      showToast(context, s.error(SocialErrorKind.offline));
      return;
    }
    setState(() => _busy = true);
    try {
      await api.leave(widget.challenge.id);
      invalidateChallenges(ref);
      if (mounted) showToast(context, cs.left);
    } on SocialError catch (e) {
      if (mounted) showToast(context, s.error(e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final cs = ChallengeStrings.of(context);
    final ch = widget.challenge;
    final board = ref.watch(challengeBoardProvider(ch.id));
    final ownId = ref.watch(socialUserIdProvider);
    final joined = ref.watch(myChallengeIdsProvider).asData?.value.contains(ch.id) ?? false;
    final now = widget.now ?? DateTime.now();
    final ended = ch.daysLeft(now) < 0;
    final (targetText, targetUnit) = s.value(ch.metric, ch.target);
    final counts = board.asData == null ? null : boardCounts(board.asData!.value);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ListView(
      key: const ValueKey('challenge-board-sheet'),
      padding: EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, bottom + Tokens.pad),
      children: [
        // ---- head ---------------------------------------------------------
        Text(cs.titleOf(ch), style: AppText.headline(c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('${s.challengeTarget.overline} ', style: AppText.label(c.textTertiary)),
            Text(targetText, style: AppText.numXs(c.textPrimary)),
            if (targetUnit != null) ...[const SizedBox(width: 4), Text(targetUnit, style: AppText.unit(c.textTertiary, size: 11))],
            const Spacer(),
            Text(ended ? cs.window(ch) : s.challengeDaysLeft(ch.daysLeft(now)), style: AppText.label(c.textTertiary)),
          ],
        ),
        if (counts != null) ...[
          const SizedBox(height: 6),
          Text(cs.counts(counts.$1, counts.$2), style: AppText.caption(c.textSecondary)),
        ],
        const SizedBox(height: Tokens.sectionGap),

        // ---- rows ---------------------------------------------------------
        board.when(
          loading: () => const _Skeleton(),
          error: (e, _) {
            final kind = e is SocialError ? e.kind : SocialErrorKind.failed;
            return switch (kind) {
              SocialErrorKind.offline => SocialStateBlock(pose: 'lean', headline: s.offlineHeadline, line: cs.offlineLine, actionLabel: cs.retry, onAction: _retry),
              SocialErrorKind.notSignedIn => SocialStateBlock(pose: 'point', headline: s.signInFirst, line: s.signedOutLine(null)),
              _ => SocialStateBlock(pose: 'lean', headline: s.error(kind), line: cs.errorLine, actionLabel: cs.retry, onAction: _retry),
            };
          },
          data: (rows) => rows.isEmpty
              ? SocialStateBlock(pose: 'carve', headline: cs.boardEmptyHeadline, line: cs.boardEmptyLine)
              : SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, e) in rows.indexed) ...[
                        if (i > 0) const Hairline(inset: 18),
                        ChallengeBoardRow(entry: e, metric: ch.metric, own: e.userId == ownId, onTap: () => RiderSheet.show(context, e.userId)),
                      ],
                    ],
                  ),
                ),
        ),

        // ---- leave --------------------------------------------------------
        if (joined && !ended) ...[
          const SizedBox(height: Tokens.sectionGap),
          SecondaryButton(key: const ValueKey('challenge-leave'), label: cs.leave, height: 48, danger: true, onPressed: _busy ? null : _leave),
        ],
      ],
    );
  }
}

/// h 64: rank (w 32) · avatar 36 · name (+ 'Du') · value numeric-s + unit ·
/// check when done. Tappable — opens the rider profile.
class ChallengeBoardRow extends StatelessWidget {
  const ChallengeBoardRow({super.key, required this.entry, required this.metric, this.own = false, this.onTap});

  final ChallengeBoardEntry entry;
  final SocialMetric metric;
  final bool own;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final (value, unit) = s.value(metric, entry.value);
    return Semantics(
      button: onTap != null,
      label: '${entry.rank}. ${entry.displayName} · ${s.valueLine(metric, entry.value)}',
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          key: ValueKey('challenge-row-${entry.userId}'),
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(width: 32, child: Text('${entry.rank}', style: AppText.numS(c.textTertiary).copyWith(fontSize: 18))),
                AvatarCircle(name: entry.displayName, size: 36, accent: own, avatarUrl: entry.avatarUrl),
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
                    Text(value, style: AppText.numS(entry.done ? c.accent : c.textPrimary)),
                    if (unit != null) ...[const SizedBox(width: 4), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
                  ],
                ),
                if (entry.done) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.check_rounded, key: ValueKey('challenge-done-${entry.userId}'), size: 18, color: c.accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three 64 pt placeholder rows at 6 % — never a Material spinner.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      key: const ValueKey('challenge-board-skeleton'),
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: Tokens.cardGap),
          Opacity(
            opacity: 0.06,
            child: Container(height: 64, decoration: ShapeDecoration(color: c.textPrimary, shape: Squircle.plain(Tokens.r20))),
          ),
        ],
      ],
    );
  }
}
