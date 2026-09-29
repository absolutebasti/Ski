import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/sync/sync_service.dart';
import 'account_providers.dart';
import 'account_strings.dart';
import 'profile_service.dart';

/// Pieces the Konto sheet and the profile page share, so the two never drift:
/// the Apple button, the signed-out body, the confirmations, the sync card,
/// the opt-in card, the home-resort card and the sign-out / delete buttons.
/// Test keys stay `account-*` in both hosts.

// ---------------------------------------------------------------- Apple button

/// Apple's capsule in the onboarding look: ink in dark, white in light, hairline
/// border, Apple glyph. Mirrors `AppleSignInButton` in features/onboarding,
/// which stays untouched.
class AccountAppleButton extends StatelessWidget {
  const AccountAppleButton({super.key, required this.label, this.onTap, this.height = 60});

  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    final fg = enabled ? c.textPrimary : c.textQuaternary;
    return Pressable(
      onTap: onTap,
      child: Container(
        key: const ValueKey('account-apple'),
        height: height,
        decoration: BoxDecoration(
          color: c.isDark ? c.ink : c.surface,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: c.hairlineStrong, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, color: fg, size: 24),
            const SizedBox(width: 10),
            Text(label, style: AppText.button(fg)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- signed out

/// Rider, one sentence, the Apple button, failure / unavailable lines.
class AccountSignedOutBody extends StatelessWidget {
  const AccountSignedOutBody({super.key, required this.onSignIn, this.failed = false, this.available = true});

  /// Null = busy or no backend → button disabled.
  final VoidCallback? onSignIn;
  final bool failed;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    return Column(
      key: const ValueKey('account-signed-out'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        const Center(child: Rider(pose: 'look', size: 132)),
        const SizedBox(height: 12),
        Text(s.signedOutLine, textAlign: TextAlign.center, style: AppText.bodyText(c.textSecondary, size: 15)),
        const SizedBox(height: 20),
        AccountAppleButton(label: s.signInWithApple, onTap: available ? onSignIn : null),
        if (failed) ...[
          const SizedBox(height: 12),
          Text(s.signInFailed, textAlign: TextAlign.center, style: AppText.caption(c.danger)),
        ],
        if (!available) ...[
          const SizedBox(height: 12),
          Text(s.unavailable, textAlign: TextAlign.center, style: AppText.caption(c.textTertiary)),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ------------------------------------------------------------------ actions

/// Sign in with Apple through the provider hook; true when a user came back.
/// Reloads the profile on success. Never throws.
Future<bool> accountSignIn(WidgetRef ref) async {
  try {
    final user = await ref.read(accountSignInProvider)();
    if (user != null) ref.invalidate(profileProvider);
    return user != null;
  } catch (_) {
    return false;
  }
}

/// Sign out and drop the cached profile. Never throws.
Future<void> accountSignOut(WidgetRef ref) async {
  try {
    await ref.read(accountSignOutProvider)();
  } catch (_) {
    // The local state is already signed out for the user.
  }
  ref.read(profileServiceProvider).clear();
  ref.invalidate(profileProvider);
}

/// Two confirmations (tap, then hold) and the deletion. Returns null when the
/// user backed out, true when deleted, false when the backend refused.
Future<bool?> accountDeleteWithConfirm(BuildContext context, WidgetRef ref) async {
  final s = AccountStrings.of(context);
  final first = await _confirm(context, title: s.deleteTitle, body: s.deleteBody, action: s.delete);
  if (!first || !context.mounted) return null;
  final second = await _confirmHold(context, title: s.deleteConfirmTitle, body: s.deleteConfirmBody, action: s.holdToDelete);
  if (!second) return null;
  try {
    await ref.read(accountDeleteProvider)();
    ref.read(profileServiceProvider).clear();
    ref.invalidate(profileProvider);
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> _confirm(BuildContext context, {required String title, required String body, required String action}) async {
  final s = AccountStrings.of(context);
  final ok = await AppSheet.show<bool>(
    context,
    builder: (ctx) => _ConfirmBody(
      title: title,
      body: body,
      action: SecondaryButton(
        key: const ValueKey('account-delete-1'),
        label: action,
        icon: Icons.delete_outline_rounded,
        danger: true,
        onPressed: () => Navigator.of(ctx).pop(true),
      ),
      cancel: s.cancel,
    ),
  );
  return ok ?? false;
}

Future<bool> _confirmHold(BuildContext context, {required String title, required String body, required String action}) async {
  final s = AccountStrings.of(context);
  final ok = await AppSheet.show<bool>(
    context,
    builder: (ctx) => _ConfirmBody(
      title: title,
      body: body,
      action: HoldToConfirmButton(
        key: const ValueKey('account-delete-2'),
        label: action,
        icon: Icons.delete_outline_rounded,
        onConfirmed: () => Navigator.of(ctx).pop(true),
      ),
      cancel: s.cancel,
    ),
  );
  return ok ?? false;
}

/// Shared body of the two delete confirmations.
class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({required this.title, required this.body, required this.action, required this.cancel});
  final String title;
  final String body;
  final Widget action;
  final String cancel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(title, style: AppText.headline(c.textPrimary)),
        const SizedBox(height: 8),
        Text(body, style: AppText.bodyText(c.textSecondary, size: 15)),
        const SizedBox(height: 20),
        action,
        const SizedBox(height: 10),
        Center(
          child: SecondaryButton(
            key: const ValueKey('account-confirm-cancel'),
            label: cancel,
            height: 48,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// 'Abmelden' and the danger 'Konto löschen'.
class AccountDangerActions extends StatelessWidget {
  const AccountDangerActions({super.key, required this.onSignOut, required this.onDelete});

  final VoidCallback? onSignOut;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AccountStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SecondaryButton(key: const ValueKey('account-sign-out'), label: s.signOut, icon: Icons.logout_rounded, onPressed: onSignOut),
        const SizedBox(height: 10),
        SecondaryButton(
          key: const ValueKey('account-delete'),
          label: s.deleteAccount,
          icon: Icons.delete_outline_rounded,
          danger: true,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- cards

/// Home resort: name or 'Nicht gewählt', chevron; [onTap] opens the picker.
class HomeResortCard extends ConsumerWidget {
  const HomeResortCard({super.key, required this.resortId, required this.onTap});

  final String? resortId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    final resort = ref.watch(resortRepositoryProvider).asData?.value.byId(resortId ?? '');
    return AppCard(
      header: s.homeResort,
      onTap: onTap,
      child: Row(
        key: const ValueKey('account-resort'),
        children: [
          Expanded(
            child: Text(
              resort?.name ?? (resortId ?? s.noResort),
              style: AppText.title(resortId == null ? c.textSecondary : c.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GlyphIcon(Glyph.chevronRight, size: 16, color: c.textTertiary),
        ],
      ),
    );
  }
}

/// 'In Ranglisten erscheinen' with the hint and the switch.
class ShareOptInCard extends StatelessWidget {
  const ShareOptInCard({super.key, required this.value, required this.onChanged});

  final bool value;

  /// Null while the profile is not loaded yet → switch disabled.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.share, style: AppText.title(c.textPrimary)),
                const SizedBox(height: 4),
                Text(s.shareHint, style: AppText.caption(c.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            key: const ValueKey('account-share-switch'),
            value: value,
            onChanged: onChanged == null
                ? null
                : (on) {
                    unawaited(HapticFeedback.selectionClick());
                    onChanged!(on);
                  },
          ),
        ],
      ),
    );
  }
}

/// Status line + 'Jetzt synchronisieren'. Owns its busy flag.
class SyncCard extends ConsumerStatefulWidget {
  const SyncCard({super.key});

  @override
  ConsumerState<SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends ConsumerState<SyncCard> {
  bool _busy = false;

  Future<void> _syncNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountSyncTriggerProvider)();
    } catch (_) {
      // Status line carries the failure; never throw out of the card.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _line(BuildContext context) {
    final s = AccountStrings.of(context);
    final l = AppLocale.of(context);
    final status = ref.watch(accountSyncStatusProvider).value ?? const SyncStatus();
    if (status.needsSignIn) return s.reSignIn;
    return switch (status.state) {
      SyncState.syncing => s.syncing,
      SyncState.offline => s.syncOffline,
      SyncState.error => s.syncError,
      SyncState.idle => status.lastSyncAt == null
          ? (status.pending == 0 ? s.neverSynced : '${s.neverSynced} · ${s.pendingCount(status.pending)}')
          : s.syncLine(Fmt.timeOfDay(status.lastSyncAt!, locale: l.code), status.pending),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_line(context), key: const ValueKey('account-sync-line'), style: AppText.bodyText(c.textSecondary, size: 15)),
          const SizedBox(height: 14),
          SecondaryButton(
            key: const ValueKey('account-sync-now'),
            label: s.syncNow,
            icon: Icons.sync_rounded,
            height: 48,
            onPressed: _busy ? null : _syncNow,
          ),
        ],
      ),
    );
  }
}

/// Section overline with the sheet's tighter padding.
class AccountSection extends StatelessWidget {
  const AccountSection(this.text, {super.key, this.first = false});
  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => SectionLabel(text, padding: EdgeInsets.only(top: first ? 4 : 24, bottom: 8));
}

/// Gap between two cards.
const SizedBox accountCardGap = SizedBox(height: Tokens.cardGap);
