import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import 'moderation_api.dart';
import 'moderation_providers.dart';
import 'moderation_strings.dart';

/// 'Blockieren' confirmation (SOC-MODERATION). Confirming performs the block
/// via [ModerationService.block] inside the sheet and closes it with true.
class BlockConfirmSheet {
  const BlockConfirmSheet._();

  /// Resolves true when the rider was blocked.
  static Future<bool> show(BuildContext context, {required String targetUserId, required String displayName}) async {
    final blocked = await AppSheet.show<bool>(
      context,
      title: ModerationStrings.of(context).blockTitle,
      builder: (_) => BlockConfirmSheetBody(targetUserId: targetUserId, displayName: displayName),
    );
    return blocked ?? false;
  }
}

/// Body of the sheet; exposed for tests, use [BlockConfirmSheet.show] in the app.
class BlockConfirmSheetBody extends ConsumerStatefulWidget {
  const BlockConfirmSheetBody({super.key, required this.targetUserId, required this.displayName});
  final String targetUserId;
  final String displayName;

  @override
  ConsumerState<BlockConfirmSheetBody> createState() => _BlockConfirmSheetBodyState();
}

class _BlockConfirmSheetBodyState extends ConsumerState<BlockConfirmSheetBody> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    final s = ModerationStrings.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(moderationServiceProvider).block(widget.targetUserId);
      if (mounted) Navigator.of(context).maybePop(true);
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
      key: const ValueKey('block-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.blockQuestion(widget.displayName), style: AppText.title(c.textPrimary)),
        const SizedBox(height: 10),
        Text(s.blockLine, style: AppText.bodyText(c.textSecondary, size: 15)),
        const SizedBox(height: Tokens.sectionGap),
        Row(
          children: [
            Expanded(child: SecondaryButton(key: const ValueKey('block-cancel'), label: s.cancel, onPressed: _busy ? null : () => Navigator.of(context).maybePop(false))),
            const SizedBox(width: 10),
            Expanded(child: SecondaryButton(key: const ValueKey('block-confirm'), label: s.blockConfirm, danger: true, onPressed: _busy ? null : _confirm)),
          ],
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}
