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

/// Card in the Heute dock when an active day was interrupted for > 30 min
/// (docs/DESIGN.md §5 "Heute — idle"). Three ways out, no silent choice.
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
      tone: CardTone.ice,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, size: 20, color: c.ice),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.interrupted(Fmt.dateShort(info.startedAt, locale: l.code)), style: AppText.bodyStrong(c.textPrimary)),
                    if (info.resortName != null) ...[
                      const SizedBox(height: 2),
                      Text(info.resortName!, style: AppText.caption(c.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MetricStrip(
            size: 22,
            items: [
              ('${info.runCount}', s.runs),
              (Fmt.metres(info.dropM, locale: l.code), s.unitHm),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              label: s.finishAndSave,
              icon: Icons.save_alt_rounded,
              height: 48,
              onPressed: _busy ? null : _finish,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: s.resume, height: 48, onPressed: _busy ? null : _resume)),
              const SizedBox(width: 8),
              Expanded(child: SecondaryButton(label: s.discard, height: 48, danger: true, onPressed: _busy ? null : _discard)),
            ],
          ),
        ],
      ),
    );
  }
}
