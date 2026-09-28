import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import 'moderation_api.dart';
import 'moderation_providers.dart';
import 'moderation_strings.dart';

/// 'Melden' (SOC-MODERATION): three reason chips, an optional note ≤ 200
/// characters, one button. On success the sheet closes and a toast says
/// 'Danke, wir schauen uns das an'.
class ReportSheet {
  const ReportSheet._();

  /// Resolves true when a report was sent.
  static Future<bool> show(BuildContext context, {required String targetUserId, required String displayName}) async {
    final sent = await AppSheet.show<bool>(
      context,
      title: ModerationStrings.of(context).reportTitle,
      builder: (_) => ReportSheetBody(targetUserId: targetUserId, displayName: displayName),
    );
    return sent ?? false;
  }
}

/// Body of the sheet; exposed for tests, use [ReportSheet.show] in the app.
class ReportSheetBody extends ConsumerStatefulWidget {
  const ReportSheetBody({super.key, required this.targetUserId, required this.displayName});
  final String targetUserId;
  final String displayName;

  @override
  ConsumerState<ReportSheetBody> createState() => _ReportSheetBodyState();
}

class _ReportSheetBodyState extends ConsumerState<ReportSheetBody> {
  ReportReason? _reason;
  final TextEditingController _details = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    final s = ModerationStrings.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(moderationServiceProvider).report(targetUserId: widget.targetUserId, reason: reason.encode(_details.text));
      if (!mounted) return;
      showToast(context, s.reportThanks);
      Navigator.of(context).maybePop(true);
    } on ModerationError catch (e) {
      if (mounted) showToast(context, s.error(e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = ModerationStrings.of(context);
    return Column(
      key: const ValueKey('report-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.reportQuestion(widget.displayName), style: AppText.bodyText(c.textSecondary, size: 15)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in ReportReason.values)
              Pressable(
                key: ValueKey('report-reason-${r.name}'),
                onTap: _busy ? null : () => setState(() => _reason = r),
                child: StateChip(text: s.reason(r), tone: _reason == r ? ChipTone.accent : ChipTone.neutral),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: ShapeDecoration(color: c.surfaceRaised, shape: Squircle.border(Tokens.r14, side: c.hairline, width: c.hairlineWidth)),
          child: TextField(
            key: const ValueKey('report-details'),
            controller: _details,
            minLines: 2,
            maxLines: 4,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(ReportReason.maxReasonLength - ReportReason.other.wire.length - 2)],
            cursorColor: c.accent,
            style: AppText.bodyText(c.textPrimary, size: 15),
            decoration: InputDecoration.collapsed(hintText: s.detailsHint, hintStyle: AppText.bodyText(c.textTertiary, size: 15)),
          ),
        ),
        const SizedBox(height: 12),
        Text(s.reportLine, style: AppText.caption(c.textTertiary, size: 12)),
        const SizedBox(height: 20),
        PrimaryButton(key: const ValueKey('report-submit'), label: s.reportSubmit, height: 52, glow: false, onPressed: _reason == null || _busy ? null : _submit),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}
