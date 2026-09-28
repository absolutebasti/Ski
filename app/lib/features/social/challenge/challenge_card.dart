import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import '../../../data/db/providers.dart';
import '../social_api.dart';
import '../social_models.dart';
import '../social_strings.dart';
import 'challenge_api.dart';
import 'challenge_board_sheet.dart';
import 'challenge_models.dart';
import 'challenge_providers.dart';
import 'challenge_strings.dart';

/// Wochen-Challenge (SOC-CHALLENGE): one target, the own progress bar computed
/// locally from the finished days inside the window, 'n dabei · m geschafft'
/// from the server board, and 'Mitmachen' — which inserts the participant row
/// and nothing else; the value is the server's business. Tapping the card
/// opens the [ChallengeBoardSheet]. Below the card: the ended challenges the
/// user took part in ([ChallengeHistoryList]).
class ChallengeCard extends ConsumerStatefulWidget {
  const ChallengeCard({super.key, required this.challenge, this.now, this.showHistory = true});

  final Challenge challenge;

  /// Injectable clock for the 'Noch 3 Tage' line.
  final DateTime? now;

  /// Renders [ChallengeHistoryList] under the card.
  final bool showHistory;

  @override
  ConsumerState<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends ConsumerState<ChallengeCard> {
  bool _busy = false;

  Future<void> _join() async {
    final api = ref.read(challengeApiProvider);
    final s = SocialStrings.of(context);
    final cs = ChallengeStrings.of(context);
    if (api == null) {
      showToast(context, s.error(SocialErrorKind.offline));
      return;
    }
    if (api.userId == null) {
      showToast(context, s.signInFirst);
      return;
    }
    setState(() => _busy = true);
    try {
      await api.join(widget.challenge.id);
      unawaited(HapticFeedback.mediumImpact());
      invalidateChallenges(ref);
      if (mounted) showToast(context, s.challengeJoined, icon: Icons.check_rounded);
    } on SocialError catch (e) {
      if (mounted) showToast(context, e.detail == kChallengeEnded ? cs.ended : s.error(e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openBoard() => ChallengeBoardSheet.show(context, widget.challenge, now: widget.now);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final cs = ChallengeStrings.of(context);
    final ch = widget.challenge;
    final days = ref.watch(daysListProvider).asData?.value ?? const <DaySummary>[];
    final joined = ref.watch(myChallengeIdsProvider).asData?.value.contains(ch.id) ?? false;
    final board = ref.watch(challengeBoardProvider(ch.id)).asData?.value;
    final value = localProgress(days, ch);
    final ratio = ch.target <= 0 ? 0.0 : (value / ch.target).clamp(0.0, 1.0).toDouble();
    final (valueText, unit) = s.value(ch.metric, value);
    final (targetText, targetUnit) = s.value(ch.metric, ch.target);
    final counts = board == null ? null : boardCounts(board);

    final card = AppCard(
      header: s.challenge,
      trailing: Text(s.challengeDaysLeft(ch.daysLeft(widget.now ?? DateTime.now())), style: AppText.label(c.textTertiary)),
      onTap: _openBoard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cs.titleOf(ch), style: AppText.title(c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible on both sides: '4.120 hm' vs 'ZIEL 5.000 hm' must share 353 pt without overflow.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(valueText, style: AppText.numM(c.accent)),
                      if (unit != null) ...[const SizedBox(width: 5), Text(unit, style: AppText.unit(c.textTertiary, size: 13))],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${s.challengeTarget.overline} ', style: AppText.label(c.textTertiary)),
                      Text(targetText, style: AppText.numXs(c.textPrimary)),
                      if (targetUnit != null) ...[const SizedBox(width: 4), Text(targetUnit, style: AppText.unit(c.textTertiary, size: 11))],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ChallengeProgressBar(ratio: ratio),
          if (counts != null) ...[
            const SizedBox(height: 10),
            Text(
              cs.counts(counts.$1, counts.$2),
              key: const ValueKey('challenge-counts'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(c.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          if (joined)
            Row(
              children: [
                StateChip(text: s.challengeIn, tone: ChipTone.accent, icon: Icons.check_rounded),
                const Spacer(),
                SecondaryButton(key: const ValueKey('challenge-board'), label: cs.openBoard, glyph: Glyph.podium, height: 44, onPressed: _openBoard),
              ],
            )
          else
            PrimaryButton(key: const ValueKey('challenge-join'), label: s.challengeJoin, height: 52, glow: false, onPressed: _busy ? null : _join),
        ],
      ),
    );

    if (!widget.showHistory) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [card, ChallengeHistoryList(now: widget.now)],
    );
  }
}

/// h 8 track with the champagne fill.
class ChallengeProgressBar extends StatelessWidget {
  const ChallengeProgressBar({super.key, required this.ratio});
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.r4),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.hairline),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: DecoratedBox(decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(Tokens.r4))),
            ),
          ],
        ),
      ),
    );
  }
}

/// 'BISHERIGE CHALLENGES' — the ended challenges the user joined, newest
/// first, each with rank, final value and a Geschafft chip. Nothing is drawn
/// while there is no history (signed out, offline, first season).
class ChallengeHistoryList extends ConsumerWidget {
  const ChallengeHistoryList({super.key, this.now});

  /// Injectable clock, handed on to the board sheet.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final cs = ChallengeStrings.of(context);
    final rows = ref.watch(challengeHistoryProvider).asData?.value ?? const <ChallengeHistoryEntry>[];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('challenge-history'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(cs.history, padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10)),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, h) in rows.indexed) ...[
                if (i > 0) const Hairline(inset: 18),
                Pressable(
                  onTap: () => ChallengeBoardSheet.show(context, h.challenge, now: now),
                  child: Padding(
                    key: ValueKey('challenge-history-${h.challenge.id}'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(cs.titleOf(h.challenge), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyText(c.textPrimary, size: 16, weight: FontWeight.w500)),
                              const SizedBox(height: 3),
                              Text(
                                '${cs.rankOf(h.rank, h.participants)} · ${s.valueLine(h.challenge.metric, h.value)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption(c.textTertiary, size: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        StateChip(text: h.done ? cs.done : cs.notDone, tone: h.done ? ChipTone.accent : ChipTone.neutral, icon: h.done ? Icons.check_rounded : null),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
