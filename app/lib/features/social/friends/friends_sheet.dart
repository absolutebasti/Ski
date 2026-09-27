import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../data/sync/auth_service.dart';
import '../social_controls.dart';
import '../social_models.dart';
import 'friends_api.dart';
import 'friends_models.dart';
import 'friends_providers.dart';
import 'friends_strings.dart';

/// Freunde sheet (SOC-FRIENDS): own code big with 'Teilen', code entry,
/// pending requests with accept / decline, friend list with swipe-to-remove.
///
/// Works signed out (one line), without a backend (offline line + retry) and
/// never blocks on the network.
class FriendsSheet {
  const FriendsSheet._();

  static Future<void> show(BuildContext context) => AppSheet.show<void>(
        context,
        expand: true,
        title: FriendsStrings.of(context).title,
        builder: (_) => const FriendsSheetBody(),
      );
}

/// Exposed for tests; use [FriendsSheet.show] in the app.
class FriendsSheetBody extends ConsumerStatefulWidget {
  const FriendsSheetBody({super.key});

  @override
  ConsumerState<FriendsSheetBody> createState() => _FriendsSheetBodyState();
}

class _FriendsSheetBodyState extends ConsumerState<FriendsSheetBody> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _codeValid => FriendCode.isValid(FriendCode.normalise(_code.text));

  // ---------------------------------------------------------------- actions

  Future<void> _run(Future<void> Function(FriendsApi api) op) async {
    final s = FriendsStrings.of(context);
    final api = ref.read(friendsApiProvider);
    if (api == null) {
      showToast(context, s.error(FriendsErrorKind.offline));
      return;
    }
    setState(() => _busy = true);
    try {
      await op(api);
      invalidateFriends(ref);
    } on FriendsError catch (e) {
      if (mounted) showToast(context, s.error(e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(String code) async {
    final s = FriendsStrings.of(context);
    await ref.read(friendsShareProvider)(s.shareText(code), subject: s.title);
  }

  Future<void> _copy(String code) async {
    final s = FriendsStrings.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    showToast(context, s.copied, icon: Icons.check_rounded);
  }

  Future<void> _add() => _run((api) async {
        final s = FriendsStrings.of(context);
        final friend = await api.addFriendByCode(_code.text);
        _code.clear();
        if (mounted) showToast(context, friend.isAccepted ? s.nowFriends : s.requestSent, icon: Icons.check_rounded);
      });

  Future<void> _accept(Friend f) => _run((api) async {
        unawaited(HapticFeedback.selectionClick());
        await api.acceptFriend(f.userId);
        if (mounted) showToast(context, FriendsStrings.of(context).accepted, icon: Icons.check_rounded);
      });

  Future<void> _decline(Friend f) => _run((api) async {
        await api.removeFriend(f.userId);
        if (mounted) showToast(context, FriendsStrings.of(context).declined);
      });

  Future<void> _withdraw(Friend f) => _run((api) => api.removeFriend(f.userId));

  /// Swipe handler: true = row may disappear.
  Future<bool> _remove(Friend f) async {
    var ok = false;
    await _run((api) async {
      await api.removeFriend(f.userId);
      ok = true;
    });
    if (ok && mounted) showToast(context, FriendsStrings.of(context).removed);
    return ok;
  }

  void _retry() {
    invalidateFriends(ref);
    ref.invalidate(myFriendCodeProvider);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = FriendsStrings.of(context);
    final api = ref.watch(friendsApiProvider);
    final auth = ref.watch(authStateProvider);
    final signedIn = auth.asData?.value != null || api?.userId != null;
    final bottom = MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom;

    if (api == null) {
      return _Line(key: const ValueKey('friends-offline'), pose: 'lean', line: s.offlineLine, actionLabel: s.retry, onAction: _retry);
    }
    if (!signedIn) {
      return _Line(key: const ValueKey('friends-signed-out'), pose: 'look', line: s.signedOutLine);
    }

    final code = ref.watch(myFriendCodeProvider).asData?.value;
    final rows = ref.watch(friendshipsProvider);
    final incoming = ref.watch(pendingRequestsProvider).asData?.value ?? const <Friend>[];
    final sent = ref.watch(sentRequestsProvider).asData?.value ?? const <Friend>[];
    final friends = ref.watch(friendsProvider).asData?.value ?? const <Friend>[];

    return ListView(
      key: const ValueKey('friends-signed-in'),
      padding: EdgeInsets.fromLTRB(0, 4, 0, bottom + Tokens.pad),
      children: [
        _CodeCard(code: code, busy: _busy, onShare: code == null ? null : () => _share(code), onCopy: code == null ? null : () => _copy(code)),
        SectionLabel(s.addFriend, padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10)),
        _CodeEntry(controller: _code, hint: s.codeHint, action: s.add, onSubmit: _busy || !_codeValid ? null : _add),
        if (rows.hasError && !rows.hasValue) ...[
          const SizedBox(height: Tokens.sectionGap),
          _Line(
            pose: 'lean',
            line: s.error(rows.error is FriendsError ? (rows.error! as FriendsError).kind : FriendsErrorKind.failed),
            actionLabel: s.retry,
            onAction: _retry,
          ),
        ] else if (rows.isLoading && !rows.hasValue) ...[
          const SizedBox(height: Tokens.sectionGap),
          const _Skeleton(),
        ] else ...[
          if (incoming.isNotEmpty) ...[
            SectionLabel(
              s.requests,
              padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10),
              trailing: Text('${incoming.length}', style: AppText.numXs(c.accent)),
            ),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, f) in incoming.indexed) ...[
                    if (i > 0) const Hairline(inset: 18),
                    _RequestRow(friend: f, busy: _busy, onAccept: () => _accept(f), onDecline: () => _decline(f)),
                  ],
                ],
              ),
            ),
          ],
          if (sent.isNotEmpty) ...[
            SectionLabel(s.sent, padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10)),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, f) in sent.indexed) ...[
                    if (i > 0) const Hairline(inset: 18),
                    _SentRow(friend: f, busy: _busy, onWithdraw: () => _withdraw(f)),
                  ],
                ],
              ),
            ),
          ],
          SectionLabel(
            s.friendsCount(friends.length),
            padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10),
            trailing: friends.isEmpty ? null : Text(s.swipeHint, style: AppText.caption(c.textTertiary, size: 12)),
          ),
          if (friends.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: RiderLine(s.emptyLine))
          else
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, f) in friends.indexed) ...[
                    if (i > 0) const Hairline(inset: 18),
                    _FriendRow(friend: f, label: s.remove, onRemove: () => _remove(f)),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Own code: overline ABOVE the code numeral, one line, Teilen + Kopieren.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.busy, this.onShare, this.onCopy});
  final String? code;
  final bool busy;
  final VoidCallback? onShare;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = FriendsStrings.of(context);
    return AppCard(
      tone: CardTone.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.myCode.overline, style: AppText.label(c.textTertiary)),
          const SizedBox(height: 10),
          Text(
            code ?? '······',
            key: const ValueKey('friends-my-code'),
            style: AppText.numL(code == null ? c.textQuaternary : c.accent).copyWith(letterSpacing: 6),
            maxLines: 1,
          ),
          const SizedBox(height: 10),
          Text(code == null ? s.codeUnavailable : s.myCodeLine, style: AppText.caption(c.textSecondary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  key: const ValueKey('friends-share'),
                  label: s.share,
                  glyph: Glyph.share,
                  height: 52,
                  glow: false,
                  onPressed: busy ? null : onShare,
                ),
              ),
              const SizedBox(width: 10),
              SecondaryButton(key: const ValueKey('friends-copy'), label: s.copy, height: 52, onPressed: busy ? null : onCopy),
            ],
          ),
        ],
      ),
    );
  }
}

/// Six-character field with the add button beside it.
class _CodeEntry extends StatelessWidget {
  const _CodeEntry({required this.controller, required this.hint, required this.action, this.onSubmit});
  final TextEditingController controller;
  final String hint;
  final String action;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: ShapeDecoration(color: c.surfaceRaised, shape: Squircle.border(Tokens.r14, side: c.hairline, width: c.hairlineWidth)),
            child: Center(
              child: TextField(
                key: const ValueKey('friends-code-field'),
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(FriendCode.length),
                  const _UpperCaseFormatter(),
                ],
                onSubmitted: (_) => onSubmit?.call(),
                cursorColor: c.accent,
                style: AppText.numS(c.textPrimary).copyWith(letterSpacing: 3),
                decoration: InputDecoration.collapsed(hintText: hint, hintStyle: AppText.bodyText(c.textTertiary, size: 15)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SecondaryButton(key: const ValueKey('friends-add'), label: action, height: 56, onPressed: onSubmit),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase(), selection: newValue.selection);
}

/// Avatar · name + flag caption.
class _Identity extends StatelessWidget {
  const _Identity({required this.friend, this.caption});
  final Friend friend;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final flag = flagEmoji(friend.countryCode);
    return Row(
      children: [
        AvatarCircle(name: friend.displayName, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                flag.isEmpty ? friend.displayName : '${friend.displayName} $flag',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyText(c.textPrimary, size: 16, weight: FontWeight.w500),
              ),
              if (caption != null) Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(c.textTertiary, size: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.friend, required this.busy, required this.onAccept, required this.onDecline});
  final Friend friend;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final s = FriendsStrings.of(context);
    return Padding(
      key: ValueKey('friends-request-${friend.userId}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Identity(friend: friend),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  key: ValueKey('friends-accept-${friend.userId}'),
                  label: s.accept,
                  height: 44,
                  glow: false,
                  onPressed: busy ? null : onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  key: ValueKey('friends-decline-${friend.userId}'),
                  label: s.decline,
                  height: 44,
                  onPressed: busy ? null : onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentRow extends StatelessWidget {
  const _SentRow({required this.friend, required this.busy, required this.onWithdraw});
  final Friend friend;
  final bool busy;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final s = FriendsStrings.of(context);
    return Padding(
      key: ValueKey('friends-sent-${friend.userId}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(child: _Identity(friend: friend, caption: s.waiting)),
          const SizedBox(width: 12),
          SecondaryButton(key: ValueKey('friends-withdraw-${friend.userId}'), label: s.withdraw, height: 40, onPressed: busy ? null : onWithdraw),
        ],
      ),
    );
  }
}

/// One friend, h 64; swipe left reveals the danger background and removes.
class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.label, required this.onRemove});
  final Friend friend;
  final String label;
  final Future<bool> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dismissible(
      key: ValueKey('friend-${friend.userId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onRemove(),
      background: ColoredBox(
        color: c.dangerWash,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlyphIcon(Glyph.trash, size: 18, color: c.danger),
                const SizedBox(width: 8),
                Text(label, style: AppText.label(c.danger, size: 12)),
              ],
            ),
          ),
        ),
      ),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Identity(friend: friend),
        ),
      ),
    );
  }
}

/// Signed-out / offline / error: the Rider, one line, at most one action.
class _Line extends StatelessWidget {
  const _Line({super.key, required this.pose, required this.line, this.actionLabel, this.onAction});
  final String pose;
  final String line;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Center(child: Rider(pose: pose, size: 128)),
        const SizedBox(height: 12),
        RiderLine(line),
        if (actionLabel != null) ...[
          const SizedBox(height: 18),
          SecondaryButton(label: actionLabel!, height: 48, onPressed: onAction),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Three 64 pt placeholder rows at 6 % — never a Material spinner.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: Tokens.cardGap),
          Opacity(
            opacity: 0.06,
            child: Container(height: 64, decoration: ShapeDecoration(color: c.textPrimary, shape: Squircle.plain(Tokens.r20))),
          ),
        ],
      ],
    );
  }
}
