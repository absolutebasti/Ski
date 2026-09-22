import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/db/providers.dart';
import 'challenge_providers.dart';
import 'social_api.dart';
import 'social_models.dart';
import 'social_strings.dart';

/// Wochen-Challenge: one target, the own progress bar computed locally from
/// the finished days inside the window, and 'Mitmachen'.
class ChallengeCard extends ConsumerStatefulWidget {
  const ChallengeCard({super.key, required this.challenge, this.now});

  final Challenge challenge;

  /// Injectable clock for the 'Noch 3 Tage' line.
  final DateTime? now;

  @override
  ConsumerState<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends ConsumerState<ChallengeCard> {
  bool _busy = false;

  Future<void> _join(double value) async {
    final api = ref.read(socialApiProvider);
    final s = SocialStrings.of(context);
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
      await api.setProgress(widget.challenge.id, value);
      ref.invalidate(challengeProgressProvider);
      if (mounted) showToast(context, s.challengeJoined);
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
    final ch = widget.challenge;
    final days = ref.watch(daysListProvider).asData?.value ?? const <DaySummary>[];
    final progress = ref.watch(challengeProgressProvider).asData?.value ?? const <String, double>{};
    final value = localProgress(days, ch);
    final joined = progress.containsKey(ch.id);
    final ratio = ch.target <= 0 ? 0.0 : (value / ch.target).clamp(0.0, 1.0).toDouble();
    final (valueText, unit) = s.value(ch.metric, value);
    final (targetText, targetUnit) = s.value(ch.metric, ch.target);

    return AppCard(
      header: s.challenge,
      trailing: Text(s.challengeDaysLeft(ch.daysLeft(widget.now ?? DateTime.now())), style: AppText.label(c.textTertiary)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ch.title, style: AppText.title(c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(valueText, style: AppText.numM(c.accent)),
              if (unit != null) ...[const SizedBox(width: 5), Text(unit, style: AppText.unit(c.textTertiary, size: 13))],
              const Spacer(),
              Text('${s.challengeTarget.overline} ', style: AppText.label(c.textTertiary)),
              Text(targetText, style: AppText.numXs(c.textPrimary)),
              if (targetUnit != null) ...[const SizedBox(width: 4), Text(targetUnit, style: AppText.unit(c.textTertiary, size: 11))],
            ],
          ),
          const SizedBox(height: 12),
          _ProgressBar(ratio: ratio),
          const SizedBox(height: 14),
          if (joined)
            Row(
              children: [
                StateChip(text: s.challengeIn, tone: ChipTone.accent, icon: Icons.check_rounded),
                const Spacer(),
                SecondaryButton(label: s.challengeUpdate, height: 44, onPressed: _busy ? null : () => _join(value)),
              ],
            )
          else
            PrimaryButton(label: s.challengeJoin, height: 52, glow: false, onPressed: _busy ? null : () => _join(value)),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.ratio});
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
