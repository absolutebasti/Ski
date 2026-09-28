import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/settings.dart';
import '../../data/sync/auth_service.dart';
import '../social/moderation/display_name_policy.dart';
import '../social/moderation/name_rules.dart';
import 'account_providers.dart';
import 'account_strings.dart';
import 'account_widgets.dart';
import 'profile_service.dart';
import 'resort_picker.dart';

/// Konto sheet (WP-15): sign in with Apple, name, home resort, leaderboard
/// opt-in, sync, sign out and account deletion. Everything degrades gracefully
/// offline. The full profile (avatar, team, level, friends) is [ProfilePage]
/// in profile_page.dart — the Einstellungen row opens that one.
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
  String? _nameHint;
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
    final ok = await accountSignIn(ref);
    if (mounted) {
      setState(() {
        _busy = false;
        _signInFailed = !ok;
      });
    }
  }

  Future<void> _saveName() async {
    final raw = _name.text;
    final hint = DisplayNamePolicy.validate(raw, locale: AppLocale.of(context));
    if (hint != null) {
      setState(() => _nameHint = hint);
      return;
    }
    setState(() {
      _editingName = false;
      _nameHint = null;
    });
    await _service.update(displayName: DisplayNamePolicy.normalized(raw));
    if (!mounted) return;
    showToast(context, AccountStrings.of(context).savedToast, icon: Icons.check_rounded);
  }

  Future<void> _pickResort(String? current) async {
    final choice = await ResortPicker.show(context, selectedId: current);
    if (choice == null) return;
    await _service.update(homeResortId: choice.resortId);
    if (choice.resortId != null) {
      await ref.read(settingsProvider.notifier).setLastResort(choice.resortId);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await accountSignOut(ref);
    if (!mounted) return;
    setState(() => _busy = false);
    showToast(context, AccountStrings.of(context).signedOutToast);
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final s = AccountStrings.of(context);
    setState(() => _busy = true);
    final result = await accountDeleteWithConfirm(context, ref);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) return;
    showToast(context, result ? s.deletedToast : s.somethingWrong);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final user = watchAuthUser(ref);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.78),
      child: SingleChildScrollView(
        child: user == null
            ? AccountSignedOutBody(
                onSignIn: _busy ? null : _signIn,
                failed: _signInFailed,
                available: ref.watch(accountAvailableProvider),
              )
            : _buildSignedIn(context, user),
      ),
    );
  }

  Widget _buildSignedIn(BuildContext context, AuthUser user) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    final profile = ref.watch(profileProvider).value;
    final name = profile?.displayName ?? user.displayName;
    final resortId = profile?.homeResortId;
    return Column(
      key: const ValueKey('account-signed-in'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AccountSection(s.sectionProfile, first: true),
        AppCard(
          header: s.displayName,
          child: _editingName
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('account-name-field'),
                            controller: _name,
                            autofocus: true,
                            maxLength: NameRules.maxLength,
                            inputFormatters: [LengthLimitingTextInputFormatter(NameRules.maxLength)],
                            textInputAction: TextInputAction.done,
                            onChanged: (_) {
                              if (_nameHint != null) setState(() => _nameHint = null);
                            },
                            onSubmitted: (_) => _saveName(),
                            style: AppText.title(c.textPrimary),
                            cursorColor: c.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              counterText: '',
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
                    ),
                    if (_nameHint != null) ...[
                      const SizedBox(height: 6),
                      Text(_nameHint!, key: const ValueKey('account-name-hint'), style: AppText.caption(c.danger)),
                    ],
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
                        setState(() {
                          _editingName = true;
                          _nameHint = null;
                        });
                      },
                    ),
                  ],
                ),
        ),
        accountCardGap,
        HomeResortCard(resortId: resortId, onTap: () => _pickResort(resortId)),
        accountCardGap,
        ShareOptInCard(
          value: profile?.shareLeaderboards ?? false,
          onChanged: profile == null ? null : (on) => _service.update(shareLeaderboards: on),
        ),
        AccountSection(s.sectionSync),
        const SyncCard(),
        AccountSection(s.sectionAccount),
        AccountDangerActions(onSignOut: _busy ? null : _signOut, onDelete: _busy ? null : _deleteAccount),
        const SizedBox(height: 8),
      ],
    );
  }
}
