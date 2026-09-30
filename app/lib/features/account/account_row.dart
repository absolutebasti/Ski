import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../social/rider_name.dart';
import '../social/social_controls.dart';
import 'account_providers.dart';
import 'account_strings.dart';
import 'profile_page.dart';
import 'profile_service.dart';

/// One embeddable row for the Einstellungen sheet: avatar (picture or
/// initial), display name and e-mail — or, signed out, 'Konto' with the
/// caption 'Anmelden – Sichern, Ranglisten, Freunde', matching the page it
/// opens. Tapping opens [ProfilePage] unless [onTap] overrides it.
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
    final name = signedIn ? riderName(context, profile?.displayName ?? user.displayName) : s.title;
    final initial = signedIn ? (profile?.initial ?? _initialOf(name)) : null;

    return Pressable(
      onTap: onTap ?? () => ProfilePage.open(context),
      child: Container(
        key: const ValueKey('account-row'),
        constraints: const BoxConstraints(minHeight: Tokens.minTarget),
        // Same 18 pt insets as a SettingsRow: the avatar lines up with the
        // row glyphs and the chevron with theirs (it sat on the card edge).
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        color: Colors.transparent,
        child: Row(
          children: [
            if (signedIn && profile?.avatarUrl != null)
              AvatarCircle(name: name, avatarUrl: profile?.avatarUrl, size: 36, accent: true)
            else
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
                    signedIn ? name : s.title,
                    style: AppText.bodyText(c.textPrimary, size: 17, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signedIn ? (user.email ?? s.signedInAs) : s.rowHint,
                    style: AppText.caption(c.textSecondary),
                    // Two lines like every SettingsRow caption: with the row's
                    // 18 pt insets the signed-out hint no longer fits one.
                    maxLines: signedIn ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const RowChevron(),
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
