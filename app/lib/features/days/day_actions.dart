import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../data/db/providers.dart';
import '../share/share_service.dart';
import 'days_strings.dart';

/// Long-press menu on a day card.
enum DayMenuAction { share, delete }

/// Which file the share button hands to the system sheet.
enum DayShareAction { card, gpx }

/// Teilen / Löschen for one day.
Future<DayMenuAction?> showDayMenu(BuildContext context) {
  final s = DaysStrings.of(context);
  return AppSheet.show<DayMenuAction>(
    context,
    title: s.dayTitle,
    builder: (ctx) => _SheetBody(
      children: [
        SheetActionRow(
          glyph: Glyph.share,
          label: s.share,
          onTap: () => Navigator.of(ctx).pop(DayMenuAction.share),
        ),
        const Hairline(inset: 38),
        SheetActionRow(
          glyph: Glyph.trash,
          label: s.delete,
          danger: true,
          onTap: () => Navigator.of(ctx).pop(DayMenuAction.delete),
        ),
      ],
    ),
  );
}

/// Bild (PNG card) or GPX.
Future<DayShareAction?> showShareMenu(BuildContext context) {
  final s = DaysStrings.of(context);
  return AppSheet.show<DayShareAction>(
    context,
    title: s.shareTitle,
    builder: (ctx) => _SheetBody(
      children: [
        SheetActionRow(
          icon: Icons.image_rounded,
          label: s.shareCard,
          onTap: () => Navigator.of(ctx).pop(DayShareAction.card),
        ),
        const Hairline(inset: 38),
        SheetActionRow(
          icon: Icons.route_rounded,
          label: s.shareGpx,
          onTap: () => Navigator.of(ctx).pop(DayShareAction.gpx),
        ),
      ],
    ),
  );
}

/// Second tap before anything is removed.
Future<bool> confirmDeleteDay(BuildContext context) async {
  final s = DaysStrings.of(context);
  final ok = await AppSheet.show<bool>(
    context,
    title: s.deleteTitle,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      return _SheetBody(
        children: [
          Text(s.deleteBody, style: AppText.bodyText(c.textSecondary, size: 15)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: s.cancel, onPressed: () => Navigator.of(ctx).pop(false))),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  label: s.delete,
                  glyph: Glyph.trash,
                  danger: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Loads the full day and hands the PNG card to the share sheet.
Future<void> shareDayCardById(BuildContext context, WidgetRef ref, String dayId) async {
  final detail = await ref.read(dayDetailProvider(dayId).future);
  if (!context.mounted) return;
  await ref.read(shareServiceProvider).shareDayCard(context, detail);
}

/// Loads the full day and hands the GPX file to the share sheet.
Future<void> shareDayGpxById(WidgetRef ref, String dayId) async {
  final detail = await ref.read(dayDetailProvider(dayId).future);
  await ref.read(shareServiceProvider).shareGpx(detail);
}

/// Soft delete — the row stays on disk with `deletedAt` set.
Future<void> deleteDayById(WidgetRef ref, String dayId) => ref.read(daysRepositoryProvider).softDeleteDay(dayId);

/// A 56 pt sheet row: glyph (or icon) + label, press scale, no ripple.
class SheetActionRow extends StatelessWidget {
  const SheetActionRow({super.key, this.icon, this.glyph, required this.label, required this.onTap, this.danger = false});
  final IconData? icon;
  final Glyph? glyph;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = danger ? c.danger : c.textPrimary;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        height: Tokens.minTarget,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: glyph != null ? GlyphIcon(glyph!, size: 22, color: color) : Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: AppText.bodyStrong(color, size: 17))),
          ],
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
}
