import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../account/profile_service.dart';
import '../social/moderation/moderation_api.dart';
import '../social/moderation/moderation_providers.dart';
import '../social/rider/rider_providers.dart';
import '../social/social_controls.dart';
import 'settings_strings.dart';

/// Einstellungen › Konto › 'Blockierte Nutzer' (SETTINGS-ACCOUNT-2): every id
/// from [blockedIdsProvider] as a row with avatar and name (the
/// `blocked_riders` RPC via [blockedRidersProvider], BE-15; `rider_profile` as
/// fallback, [Profile.fallbackName] when neither knows the rider) and
/// a 'Freigeben' button that unblocks through [moderationServiceProvider] —
/// which drops [blockedIdsProvider] and every board, so the row disappears.
/// Empty: one line 'Niemand blockiert.'.
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push<void>(MaterialPageRoute<void>(builder: (_) => const BlockedUsersPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SettingsStrings.of(context);
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 40),
            children: [
              ScreenHeader(
                title: s.blockedUsers,
                leading: HeaderButton(
                  glyph: Glyph.back,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const BlockedUsersBody(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list without the scaffold; exposed for tests.
class BlockedUsersBody extends ConsumerWidget {
  const BlockedUsersBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = SettingsStrings.of(context);
    final blocked = ref.watch(blockedIdsProvider);
    // Newest block first (the RPC's order); ids it does not know yet go last.
    final riders = ref.watch(blockedRidersProvider).value ?? const <BlockedRider>[];
    final order = {for (final (i, r) in riders.indexed) r.userId: i};
    int rank(String id) => order[id] ?? riders.length;
    // Keep the previous list on screen while a refetch after 'Freigeben' runs.
    final ids = (blocked.value ?? const <String>{}).toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    final Widget body;
    if (blocked.hasError && !blocked.hasValue) {
      body = Text(s.blockedLoadFailed, key: const ValueKey('blocked-error'), style: AppText.bodyText(c.textSecondary, size: 15));
    } else if (blocked.isLoading && !blocked.hasValue) {
      body = const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
    } else if (ids.isEmpty) {
      body = Text(s.blockedNone, key: const ValueKey('blocked-empty'), style: AppText.bodyText(c.textSecondary, size: 15));
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, id) in ids.indexed) ...[
            if (i > 0) const Hairline(inset: 18),
            BlockedRow(userId: id),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Text(s.blockedIntro, style: AppText.bodyText(c.textSecondary, size: 15)),
        ),
        AppCard(padding: ids.isEmpty ? const EdgeInsets.all(Tokens.cardPad) : EdgeInsets.zero, child: body),
      ],
    );
  }
}

/// One blocked rider: avatar, name (from [blockedRidersProvider]; once that
/// has answered without a name, `riderProfileProvider`; else the fallback) and
/// 'Freigeben'. Owns its busy flag so a double tap cannot unblock twice.
class BlockedRow extends ConsumerStatefulWidget {
  const BlockedRow({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<BlockedRow> {
  bool _busy = false;

  Future<void> _unblock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = SettingsStrings.of(context);
    try {
      await ref.read(moderationServiceProvider).unblock(widget.userId);
      if (mounted) showToast(context, s.unblockedToast, icon: Icons.check_rounded);
    } on ModerationError {
      if (mounted) showToast(context, s.unblockFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SettingsStrings.of(context);
    final riders = ref.watch(blockedRidersProvider);
    final rider = riders.value?.where((r) => r.userId == widget.userId).firstOrNull;
    // rider_profile only as a fallback — and only after blocked_riders answered,
    // so a normal load costs one RPC for the whole list.
    final profile = riders.hasValue && rider?.displayName == null ? ref.watch(riderProfileProvider(widget.userId)).value : null;
    final profileName = profile?.displayName.trim();
    final name = rider?.displayName ?? (profileName != null && profileName.isNotEmpty ? profileName : Profile.fallbackName);
    final avatarUrl = rider?.avatarUrl ?? profile?.avatarUrl;
    return Padding(
      key: ValueKey('blocked-${widget.userId}'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Tokens.minTarget - 20),
        child: Row(
          children: [
            AvatarCircle(name: name, avatarUrl: avatarUrl, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: AppText.bodyStrong(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 12),
            SecondaryButton(
              key: ValueKey('unblock-${widget.userId}'),
              label: s.unblock,
              height: Tokens.buttonSm,
              onPressed: _busy ? null : _unblock,
            ),
          ],
        ),
      ),
    );
  }
}
