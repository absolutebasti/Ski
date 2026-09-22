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
    builder: (ctx) => _SheetBody(
      children: [
        SheetActionRow(
          icon: Icons.ios_share_rounded,
          label: s.share,
          onTap: () => Navigator.of(ctx).pop(DayMenuAction.share),
        ),
        SheetActionRow(
          icon: Icons.delete_outline_rounded,
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
    builder: (ctx) => _SheetBody(
      children: [
        SheetActionRow(
          icon: Icons.image_outlined,
          label: s.shareCard,
          onTap: () => Navigator.of(ctx).pop(DayShareAction.card),
        ),
        SheetActionRow(
          icon: Icons.route_outlined,
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
    builder: (ctx) {
      final c = AppColors.of(ctx);
      return _SheetBody(
        children: [
          Text(s.deleteTitle, style: AppText.title(c.textPrimary)),
          const SizedBox(height: 8),
          Text(s.deleteBody, style: AppText.bodyText(c.textSecondary, size: 15)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: s.cancel, onPressed: () => Navigator.of(ctx).pop(false))),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  label: s.delete,
                  icon: Icons.delete_outline_rounded,
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

class SheetActionRow extends StatelessWidget {
  const SheetActionRow({super.key, required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = danger ? c.danger : c.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(Tokens.radius),
      onTap: onTap,
      child: SizedBox(
        height: Tokens.minTarget,
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Text(label, style: AppText.bodyText(color, size: 17, weight: FontWeight.w600)),
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
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: c.hairline, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}
