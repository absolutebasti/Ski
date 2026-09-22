import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import 'summary_strings.dart';

/// Asked exactly once, right after the first day was saved (docs/PLAN.md §3).
/// Returns true when the user wants reminders; the caller does the iOS request.
class NotificationsOptInSheet {
  const NotificationsOptInSheet._();

  static Future<bool> show(BuildContext context) async {
    final ok = await AppSheet.show<bool>(
      context,
      dismissible: false,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        final s = SummaryStrings.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(s.notifyTitle, style: AppText.headline(c.textPrimary, size: 24)),
            const SizedBox(height: 10),
            Text(s.notifyBody, style: AppText.bodyText(c.textSecondary, size: 16)),
            const SizedBox(height: 24),
            PrimaryButton(label: s.notifyYes, onPressed: () => Navigator.of(ctx).pop(true)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [SecondaryButton(label: s.notifyNo, onPressed: () => Navigator.of(ctx).pop(false))],
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
    return ok ?? false;
  }
}
