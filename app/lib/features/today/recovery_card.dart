import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../recording/recording_controller.dart';
import '../recording/recovery_service.dart';
import 'today_strings.dart';

/// Inline card on Heute when an active day was interrupted for > 30 min
/// (docs/PLAN.md §3 row "Recovery card"). Three ways out, no silent choice.
class RecoveryCard extends ConsumerStatefulWidget {
  const RecoveryCard({super.key, required this.info});
  final RecoveryInfo info;

  @override
  ConsumerState<RecoveryCard> createState() => _RecoveryCardState();
}

class _RecoveryCardState extends ConsumerState<RecoveryCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(RecordingController c) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(recordingControllerProvider.notifier));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() => _run((c) async {
        final id = await c.endRecoveredDay(widget.info.dayId);
        if (id == null || !mounted) return;
        await AppNav.openSummary(context, id);
      });

  Future<void> _resume() => _run((c) => c.resumeDay(widget.info.dayId));

  Future<void> _discard() => _run((c) => c.discardRecoveredDay(widget.info.dayId));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final info = widget.info;
    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: c.ice),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.interrupted(Fmt.dateShort(info.startedAt, locale: l.code)),
                  style: AppText.bodyText(c.textPrimary, size: 16, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${s.runCount(info.runCount)} · ${Fmt.metres(info.dropM, locale: l.code)} ${s.unitHm}'
            '${info.resortName == null ? '' : ' · ${info.resortName}'}',
            style: AppText.bodyText(c.textSecondary, size: 15),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              label: s.finishAndSave,
              icon: Icons.save_alt_rounded,
              onPressed: _busy ? null : _finish,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: s.resume, onPressed: _busy ? null : _resume)),
              const SizedBox(width: 8),
              Expanded(child: SecondaryButton(label: s.discard, onPressed: _busy ? null : _discard)),
            ],
          ),
        ],
      ),
    );
  }
}
