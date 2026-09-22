import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import 'account_providers.dart';
import 'account_sheet.dart';
import 'account_strings.dart';
import 'profile_service.dart';

/// One embeddable row for the Einstellungen sheet: avatar initial, display
/// name (or "Anmelden" when signed out) and a chevron. Tapping opens
/// [AccountSheet] unless [onTap] overrides it.
class AccountRow extends ConsumerWidget {
  const AccountRow({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    final user = watchAuthUser(ref);
    final profile = ref.watch(profileProvider).value;
    final signedIn = user != null;
    final name = profile?.displayName ?? user?.displayName ?? s.signIn;
    final initial = signedIn ? (profile?.initial ?? _initialOf(name)) : null;

    return Pressable(
      onTap: onTap ?? () => AccountSheet.show(context),
      child: Container(
        key: const ValueKey('account-row'),
        constraints: const BoxConstraints(minHeight: Tokens.minTarget),
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: signedIn ? c.accentWash : c.glassFill,
                shape: BoxShape.circle,
                border: Border.all(color: signedIn ? c.accent.withValues(alpha: 0.45) : c.glassStroke, width: c.hairlineWidth),
              ),
              child: initial == null
                  ? Icon(Icons.person_outline_rounded, size: 20, color: c.textTertiary)
                  : Text(initial, style: AppText.title(c.accent, size: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    signedIn ? name : s.signIn,
                    style: AppText.bodyText(c.textPrimary, size: 17, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signedIn ? (user.email ?? s.signedInAs) : s.rowHint,
                    style: AppText.caption(c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GlyphIcon(Glyph.chevronRight, size: 16, color: c.textTertiary),
          ],
        ),
      ),
    );
  }

  static String _initialOf(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }
}
