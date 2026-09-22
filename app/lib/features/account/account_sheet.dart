import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/sync/auth_service.dart';
import '../../data/sync/sync_service.dart';
import '../onboarding/mascot_hero.dart' show Leo;
import 'account_providers.dart';
import 'account_strings.dart';
import 'profile_service.dart';
import 'resort_picker.dart';

/// Konto sheet (WP-15): sign in with Apple, profile, leaderboard opt-in, sync,
/// sign out and account deletion. Everything degrades gracefully offline.
class AccountSheet {
  const AccountSheet._();

  static Future<void> show(BuildContext context) => AppSheet.show<void>(
        context,
        title: AccountStrings.of(context).title,
        builder: (_) => const AccountSheetBody(),
      );
}

/// Exposed for tests; use [AccountSheet.show] in the app.
class AccountSheetBody extends ConsumerStatefulWidget {
  const AccountSheetBody({super.key});

  @override
  ConsumerState<AccountSheetBody> createState() => _AccountSheetBodyState();
}

class _AccountSheetBodyState extends ConsumerState<AccountSheetBody> {
  final TextEditingController _name = TextEditingController();
  bool _editingName = false;
  bool _busy = false;
  bool _signInFailed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ProfileService get _service => ref.read(profileServiceProvider);

  // ---------------------------------------------------------------- actions

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _signInFailed = false;
    });
    try {
      final user = await ref.read(accountSignInProvider)();
      if (user != null) ref.invalidate(profileProvider);
      if (mounted && user == null) setState(() => _signInFailed = true);
    } catch (e) {
      if (mounted) setState(() => _signInFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveName() async {
    final value = _name.text.trim();
    setState(() => _editingName = false);
    if (value.isEmpty) return;
    await _service.update(displayName: value);
    if (!mounted) return;
    showToast(context, AccountStrings.of(context).savedToast, icon: Icons.check_rounded);
  }

  Future<void> _toggleShare(bool on) async {
    unawaited(HapticFeedback.selectionClick());
    await _service.update(shareLeaderboards: on);
  }

  Future<void> _pickResort(String? current) async {
    final choice = await ResortPicker.show(context, selectedId: current);
    if (choice == null) return;
    await _service.update(homeResortId: choice.resortId);
    if (choice.resortId != null) {
      await ref.read(settingsProvider.notifier).setLastResort(choice.resortId);
    }
  }

  Future<void> _syncNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountSyncTriggerProvider)();
    } catch (_) {
      // Status line carries the failure; never throw out of the sheet.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountSignOutProvider)();
      _service.clear();
      ref.invalidate(profileProvider);
    } catch (_) {
      // Ignored: the local state is already signed out for the user.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    showToast(context, AccountStrings.of(context).signedOutToast);
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final s = AccountStrings.of(context);
    final first = await _confirm(title: s.deleteTitle, body: s.deleteBody, action: s.delete);
    if (!first || !mounted) return;
    final second = await _confirmHold(title: s.deleteConfirmTitle, body: s.deleteConfirmBody, action: s.holdToDelete);
    if (!second || !mounted) return;
    setState(() => _busy = true);
    var ok = true;
    try {
      await ref.read(accountDeleteProvider)();
      _service.clear();
      ref.invalidate(profileProvider);
    } catch (_) {
      ok = false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    showToast(context, ok ? s.deletedToast : s.somethingWrong);
  }

  Future<bool> _confirm({required String title, required String body, required String action}) async {
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

  Future<bool> _confirmHold({required String title, required String body, required String action}) async {
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

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final user = watchAuthUser(ref);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.78),
      child: SingleChildScrollView(
        child: user == null ? _buildSignedOut(context) : _buildSignedIn(context, user),
      ),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    final available = ref.watch(accountAvailableProvider);
    return Column(
      key: const ValueKey('account-signed-out'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        const Center(child: Leo(pose: 'wave', size: 132)),
        const SizedBox(height: 12),
        Text(s.signedOutLine, textAlign: TextAlign.center, style: AppText.bodyText(c.textSecondary, size: 15)),
        const SizedBox(height: 20),
        _AppleButton(label: s.signInWithApple, onTap: _busy || !available ? null : _signIn),
        if (_signInFailed) ...[
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

  Widget _buildSignedIn(BuildContext context, AuthUser user) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    final profile = ref.watch(profileProvider).value;
    final name = profile?.displayName ?? user.displayName;
    final resortId = profile?.homeResortId;
    final resort = ref.watch(resortRepositoryProvider).asData?.value.byId(resortId ?? '');
    return Column(
      key: const ValueKey('account-signed-in'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(s.sectionProfile, padding: const EdgeInsets.only(top: 4, bottom: 8)),
        AppCard(
          header: s.displayName,
          child: _editingName
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('account-name-field'),
                        controller: _name,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveName(),
                        style: AppText.title(c.textPrimary),
                        cursorColor: c.accent,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: s.displayNameHint,
                          hintStyle: AppText.bodyText(c.textTertiary, size: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SecondaryButton(
                      key: const ValueKey('account-name-save'),
                      label: s.save,
                      height: 40,
                      onPressed: _saveName,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: Text(name, style: AppText.title(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 12),
                    SecondaryButton(
                      key: const ValueKey('account-name-edit'),
                      label: s.edit,
                      height: 40,
                      onPressed: () {
                        _name.text = name;
                        setState(() => _editingName = true);
                      },
                    ),
                  ],
                ),
        ),
        const SizedBox(height: Tokens.cardGap),
        AppCard(
          header: s.homeResort,
          onTap: () => _pickResort(resortId),
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
        ),
        const SizedBox(height: Tokens.cardGap),
        AppCard(
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
                value: profile?.shareLeaderboards ?? false,
                onChanged: profile == null ? null : _toggleShare,
              ),
            ],
          ),
        ),
        SectionLabel(s.sectionSync, padding: const EdgeInsets.only(top: 24, bottom: 8)),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_syncLine(context), key: const ValueKey('account-sync-line'), style: AppText.bodyText(c.textSecondary, size: 15)),
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
        ),
        SectionLabel(s.sectionAccount, padding: const EdgeInsets.only(top: 24, bottom: 8)),
        SecondaryButton(
          key: const ValueKey('account-sign-out'),
          label: s.signOut,
          icon: Icons.logout_rounded,
          onPressed: _busy ? null : _signOut,
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          key: const ValueKey('account-delete'),
          label: s.deleteAccount,
          icon: Icons.delete_outline_rounded,
          danger: true,
          onPressed: _busy ? null : _deleteAccount,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _syncLine(BuildContext context) {
    final s = AccountStrings.of(context);
    final l = AppLocale.of(context);
    final status = ref.watch(accountSyncStatusProvider).value ?? const SyncStatus();
    return switch (status.state) {
      SyncState.syncing => s.syncing,
      SyncState.offline => s.syncOffline,
      SyncState.error => s.syncError,
      SyncState.idle => status.lastSyncAt == null
          ? (status.pending == 0 ? s.neverSynced : '${s.neverSynced} · ${s.pendingCount(status.pending)}')
          : s.syncLine(Fmt.timeOfDay(status.lastSyncAt!, locale: l.code), status.pending),
    };
  }
}

/// Apple's capsule: cream on graphite in dark, black on white in light — the
/// same control as the onboarding FriendsPage.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: Container(
        key: const ValueKey('account-apple'),
        height: Tokens.minTarget,
        decoration: BoxDecoration(
          color: enabled ? c.textPrimary : c.surfaceRaised,
          borderRadius: BorderRadius.circular(Tokens.minTarget / 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, color: enabled ? c.bg : c.textQuaternary, size: 24),
            const SizedBox(width: 8),
            Text(label, style: AppText.button(enabled ? c.bg : c.textQuaternary)),
          ],
        ),
      ),
    );
  }
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
