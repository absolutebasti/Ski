import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import 'today_strings.dart';

/// Small sheet for the season goal: one 44 pt numeral, a −/+ stepper in
/// 5.000 hm steps between [minHm] and [maxHm], 'Speichern' and 'Kein Ziel'.
/// Writes `settings.setSeasonGoal` (0 = no goal, which hides the goal line).
/// Reused by the profile page's 'Saisonziel' row.
class SeasonGoalSheet extends ConsumerStatefulWidget {
  const SeasonGoalSheet({super.key});

  static const int minHm = 5000;
  static const int maxHm = 100000;
  static const int stepHm = 5000;
  static const int defaultHm = 20000;

  static Future<void> show(BuildContext context) {
    final s = TodayStrings.of(context);
    return AppSheet.show<void>(context, title: s.goalTitle, builder: (_) => const SeasonGoalSheet());
  }

  /// Snaps [hm] onto the stepper grid inside the range; ≤ 0 falls back to the default.
  static int snap(int hm) {
    if (hm <= 0) return defaultHm;
    final stepped = (hm / stepHm).round() * stepHm;
    return stepped.clamp(minHm, maxHm);
  }

  @override
  ConsumerState<SeasonGoalSheet> createState() => _SeasonGoalSheetState();
}

class _SeasonGoalSheetState extends ConsumerState<SeasonGoalSheet> {
  late int _hm = SeasonGoalSheet.snap(ref.read(settingsProvider).seasonGoalHm);

  void _step(int delta) {
    final next = (_hm + delta).clamp(SeasonGoalSheet.minHm, SeasonGoalSheet.maxHm);
    if (next == _hm) return;
    HapticFeedback.selectionClick();
    setState(() => _hm = next);
  }

  Future<void> _save(int hm) async {
    await ref.read(settingsProvider.notifier).setSeasonGoal(hm);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final canLess = _hm > SeasonGoalSheet.minHm;
    final canMore = _hm < SeasonGoalSheet.maxHm;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.goalBody, style: AppText.bodyText(c.textSecondary, size: 15)),
        const SizedBox(height: 20),
        Row(
          children: [
            _StepButton(icon: Icons.remove_rounded, label: s.goalLess, onTap: canLess ? () => _step(-SeasonGoalSheet.stepHm) : null),
            Expanded(
              child: Center(
                child: HeroNumber(
                  key: const ValueKey('season-goal-value'),
                  value: Fmt.metres(_hm.toDouble(), locale: l.code),
                  unit: s.unitHm,
                  label: s.goal,
                  size: 44,
                  color: c.accent,
                  align: CrossAxisAlignment.center,
                ),
              ),
            ),
            _StepButton(icon: Icons.add_rounded, label: s.goalMore, onTap: canMore ? () => _step(SeasonGoalSheet.stepHm) : null),
          ],
        ),
        const SizedBox(height: 24),
        PrimaryButton(key: const ValueKey('season-goal-save'), label: s.goalSave, height: 56, glow: false, onPressed: () => _save(_hm)),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: SecondaryButton(key: const ValueKey('season-goal-none'), label: s.goalNone, height: 48, onPressed: () => _save(0)))]),
      ],
    );
  }
}

/// 48 pt glass circle with a 22 pt icon; dims when the step is not possible.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        onTap: onTap,
        enabled: enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Container(
            width: Tokens.minTarget,
            height: Tokens.minTarget,
            decoration: BoxDecoration(
              color: c.glassFill,
              shape: BoxShape.circle,
              border: Border.all(color: c.glassStroke, width: c.hairlineWidth),
            ),
            child: Icon(icon, size: 22, color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}
