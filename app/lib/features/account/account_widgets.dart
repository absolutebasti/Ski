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
import '../../data/sync/sync_service.dart';
import '../achievements/achievements_providers.dart';
import '../achievements/achievements_strings.dart';
import '../achievements/ui/level_ring.dart';
import '../achievements/ui/medals_sheet.dart';
import '../achievements/ui/streak_chip.dart';
import '../today/season_goal_sheet.dart';
import 'account_providers.dart';
import 'account_strings.dart';
import 'profile_service.dart';

/// Building blocks of the profile page: the Apple button, the signed-out
/// body, the level and season-goal cards, the confirmations, the sync card,
/// the opt-in card, the home-resort card and the sign-out / delete buttons.
/// Test keys stay `account-*` / `profile-*`.

// ---------------------------------------------------------------- Apple button

/// The shared [AppleButton] (ink in dark, white in light, hairline border,
/// Apple glyph) under the account test key.
class AccountAppleButton extends StatelessWidget {
  const AccountAppleButton({super.key, required this.label, this.onTap, this.height = 60});

  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: const ValueKey('account-apple'), child: AppleButton(label: label, onPressed: onTap, height: height));
}

// -------------------------------------------------------------- signed out

/// The signed-out profile page (SETTINGS-ACCOUNT-2): rider line, the three
/// benefits, the Apple button, 'Ohne Konto weiter', then the device-computed
/// level card and the season goal — the page is as full without a Konto as
/// with one. Test keys: `account-signed-out`, `account-apple`,
/// `account-continue`, `account-benefit-*`, `profile-level`, `profile-season-goal`.
class AccountSignedOutBody extends StatelessWidget {
  const AccountSignedOutBody({super.key, required this.onSignIn, this.onContinue, this.failed = false, this.available = true});

  /// Null = busy or no backend → button disabled.
  final VoidCallback? onSignIn;

  /// 'Ohne Konto weiter' — the host pops the page. Null hides the button.
  final VoidCallback? onContinue;
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
        // Rider beside his line, not above it: the benefits, both buttons and
        // the level card fit the first screen of a 390 × 844 iPhone.
        AppCard(
          child: Row(
            children: [
              const ExcludeSemantics(child: Rider(pose: 'look', size: 84)),
              const SizedBox(width: 14),
              Expanded(child: RiderLine(s.signedOutLine)),
            ],
          ),
        ),
        AccountSection(s.sectionBenefits),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BenefitRow(key: const ValueKey('account-benefit-backup'), icon: Icons.cloud_done_outlined, title: s.benefitBackup, hint: s.benefitBackupHint),
              const Hairline(inset: 54),
              _BenefitRow(key: const ValueKey('account-benefit-boards'), glyph: Glyph.podium, title: s.benefitBoards, hint: s.benefitBoardsHint),
              const Hairline(inset: 54),
              _BenefitRow(key: const ValueKey('account-benefit-friends'), icon: Icons.people_outline_rounded, title: s.benefitFriends, hint: s.benefitFriendsHint),
            ],
          ),
        ),
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
        if (onContinue != null) ...[
          const SizedBox(height: 10),
          SecondaryButton(key: const ValueKey('account-continue'), label: s.continueWithout, onPressed: onContinue),
        ],
        AccountSection(s.sectionLevel),
        const ProfileLevelCard(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(s.deviceLevelHint, style: AppText.caption(c.textTertiary)),
        ),
        AccountSection(s.sectionSeason),
        const SeasonGoalCard(),
      ],
    );
  }
}

/// One benefit line: 22 pt icon tertiary, title 16, caption 13.5.
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({super.key, required this.title, required this.hint, this.icon, this.glyph});
  final String title;
  final String hint;
  final IconData? icon;
  final Glyph? glyph;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Tokens.minTarget - 24),
        child: Row(
          children: [
            if (glyph != null) GlyphIcon(glyph!, size: 22, color: c.accent) else Icon(icon, size: 22, color: c.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppText.bodyStrong(c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(hint, style: AppText.caption(c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- level

/// Level ring, level line, points, streak chip and the medal count from the
/// device engine ([achievementsProvider]) — the same card signed in and out;
/// tapping opens the Medaillen sheet.
class ProfileLevelCard extends ConsumerWidget {
  const ProfileLevelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(achievementsProvider);
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AchievementsStrings.of(context);
    final nextAt = a.level.nextAtM;
    final nextLine = nextAt == null ? s.topLevel : s.nextLevelShort((nextAt - a.level.distanceM).clamp(0, double.infinity), a.level.index + 1);
    return Semantics(
      label: s.openMedals,
      child: AppCard(
        onTap: () => MedalsSheet.show(context),
        child: Row(
          key: const ValueKey('profile-level'),
          children: [
            LevelRing(level: a.level, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.levelLine(a.level).overline, style: AppText.label(c.textSecondary)),
                  const SizedBox(height: 4),
                  Text(nextLine, style: AppText.caption(c.textSecondary, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  // Points left, streak right; on a narrow card (iPhone width, five
                  // digit points, large type) the chip drops to its own line
                  // instead of overflowing.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(Fmt.metres(a.points.toDouble(), locale: l.code), style: AppText.numS(c.accent)),
                            const SizedBox(width: 6),
                            Text(s.points, style: AppText.unit(c.textTertiary, size: 12)),
                          ],
                        ),
                        StreakChip(streak: a.streak, compact: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.medalCount(a.earned.length, a.medals.length), key: const ValueKey('profile-medals'), style: AppText.bodyStrong(c.textPrimary, size: 15)),
                      ),
                      const RowChevron(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- season goal

/// 'Saisonziel' row: the current goal ('25.000 hm' or 'Kein Ziel') and a
/// chevron; tapping opens [SeasonGoalSheet] from features/today, which writes
/// `settings.setSeasonGoal` (0 = no goal).
class SeasonGoalCard extends ConsumerWidget {
  const SeasonGoalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AccountStrings.of(context);
    final hm = ref.watch(settingsProvider.select((st) => st.seasonGoalHm));
    return AppCard(
      onTap: () => SeasonGoalSheet.show(context),
      child: Row(
        key: const ValueKey('profile-season-goal'),
        children: [
          Icon(Icons.flag_outlined, size: 22, color: c.textTertiary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.seasonGoal, style: AppText.bodyStrong(c.textPrimary)),
                const SizedBox(height: 2),
                Text(s.seasonGoalHint, style: AppText.caption(c.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (hm <= 0)
            Text(s.seasonGoalNone, key: const ValueKey('profile-season-goal-value'), style: AppText.bodyText(c.textSecondary, size: 16))
          else
            Row(
              key: const ValueKey('profile-season-goal-value'),
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Fmt.metres(hm.toDouble(), locale: l.code), style: AppText.numS(c.accent)),
                const SizedBox(width: 4),
                Text(s.unitHm, style: AppText.unit(c.textTertiary, size: 12)),
              ],
            ),
          const SizedBox(width: 8),
          const RowChevron(),
        ],
      ),
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
/// user backed out, true when deleted, false when the backend refused or was
/// unreachable — then nothing was deleted, the session and the cached profile
/// stay as they are.
Future<bool?> accountDeleteWithConfirm(BuildContext context, WidgetRef ref) async {
  final s = AccountStrings.of(context);
  final first = await _confirm(context, title: s.deleteTitle, body: s.deleteBody, action: s.delete);
  if (!first || !context.mounted) return null;
  final second = await _confirmHold(context, title: s.deleteConfirmTitle, body: s.deleteConfirmBody, action: s.holdToDelete);
  if (!second) return null;
  try {
    final deleted = await ref.read(accountDeleteProvider)();
    if (!deleted) return false;
    // Local sync bookkeeping of the deleted account; never holds up the UI.
    try {
      unawaited(ref.read(syncServiceProvider).forgetAccount().catchError((Object _) {}));
    } catch (_) {}
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
          child: GhostButton(
            key: const ValueKey('account-confirm-cancel'),
            label: cancel,
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
          const RowChevron(),
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
          AppSwitch(
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
      SyncState.throttled => s.syncThrottled,
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
            height: Tokens.buttonMd,
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
