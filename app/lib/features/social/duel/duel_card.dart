import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import '../invite/invite_links.dart';
import '../social_api.dart';
import '../social_controls.dart';
import '../social_models.dart';
import '../social_strings.dart';
import 'duel_api.dart';
import 'duel_history.dart';
import 'duel_models.dart';
import 'duel_providers.dart';
import 'duel_strings.dart';

/// Tagesduell — the private race of the day (docs/ONBOARDING-SOCIAL.md,
/// live since SOC-LIVE-DUEL).
///
/// Sits on top of the Rangliste while a duel is running: every member with
/// their Höhenmeter — live rows ('live · vor 2 min', ice dot) while a rider
/// is still on the slope, the leader in champagne, '2 / 3' members in the
/// header, share / leave. Without a duel it offers 'Duell starten' (with an
/// optional name) and 'Code eingeben'. Past duels list underneath
/// ([DuelHistoryList]).
///
/// The board is refetched every [duelPollIntervalProvider] while the tab is
/// visible and the app is in the foreground; override the provider with `null`
/// to switch polling off (widget tests).
class DuelCard extends ConsumerStatefulWidget {
  const DuelCard({super.key, this.resortId, this.ownUserId, this.now, this.showHistory = true});

  /// Informational only — a duel is not bound to a Gebiet (0009 dropped the
  /// resort filter); stored on the group for the result card.
  final String? resortId;
  final String? ownUserId;

  /// Clock for 'vor 2 min' and the history labels; null = the wall clock.
  final DateTime? now;

  /// Past duels under the card.
  final bool showHistory;

  @override
  ConsumerState<DuelCard> createState() => _DuelCardState();
}

class _DuelCardState extends ConsumerState<DuelCard> with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncTimer();

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Visible = the tab's tickers run and the app is in the foreground.
  void _syncTimer() {
    final interval = ref.read(duelPollIntervalProvider);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final visible = TickerMode.valuesOf(context).enabled && (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (interval == null || !visible) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(interval, (_) => _refresh());
  }

  void _refresh() {
    final duel = ref.read(myDuelProvider).asData?.value;
    if (duel == null) return;
    ref.invalidate(groupBoardProvider(duel.id));
  }

  Future<void> _run(Future<void> Function(DuelApi api) op) async {
    final api = ref.read(duelApiProvider);
    final s = SocialStrings.of(context);
    if (api == null) {
      showToast(context, s.error(SocialErrorKind.offline));
      return;
    }
    if (api.userId == null) {
      showToast(context, s.signInFirst);
      return;
    }
    setState(() => _busy = true);
    try {
      await op(api);
    } on SocialError catch (e) {
      if (mounted) showToast(context, s.error(e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final api = ref.read(duelApiProvider);
    final s = SocialStrings.of(context);
    final ds = DuelStrings.of(context);
    // Signed-out / offline: say so before opening the sheet.
    if (api == null) {
      showToast(context, s.error(SocialErrorKind.offline));
      return;
    }
    if (api.userId == null) {
      showToast(context, s.signInFirst);
      return;
    }
    final name = await AppSheet.show<String>(context, title: ds.createTitle, builder: (_) => const DuelCreateSheet());
    if (name == null || !mounted) return;
    await _run((api) async {
      final duelName = name.trim().isEmpty ? s.duelDefaultName : name.trim();
      final group = await api.createDuel(name: duelName, day: today(), tz: ref.read(deviceTimeZoneProvider), resortId: widget.resortId);
      unawaited(HapticFeedback.mediumImpact());
      ref.invalidate(myDuelProvider);
      ref.invalidate(myDuelsProvider);
      ref.invalidate(groupBoardProvider(group.id));
      if (mounted) showToast(context, s.duelCreated);
    });
  }

  Future<void> _join() async {
    final s = SocialStrings.of(context);
    final code = await AppSheet.show<String>(context, title: s.duelJoin, builder: (_) => const _JoinSheet());
    if (code == null || !mounted) return;
    await _run((api) async {
      final group = await api.joinDuel(code);
      unawaited(HapticFeedback.mediumImpact());
      ref.invalidate(myDuelProvider);
      ref.invalidate(myDuelsProvider);
      ref.invalidate(groupBoardProvider(group.id));
      if (mounted) showToast(context, s.duelJoined);
    });
  }

  Future<void> _leave(DuelGroup duel) => _run((api) async {
        final s = SocialStrings.of(context);
        await api.leaveDuel(duel.id);
        ref.invalidate(myDuelProvider);
        ref.invalidate(myDuelsProvider);
        if (mounted) showToast(context, s.duelLeft);
      });

  Future<void> _share(DuelGroup duel) async {
    final s = SocialStrings.of(context);
    await SharePlus.instance.share(ShareParams(text: DuelCardShare.text(s, duel.code), subject: s.duel));
  }

  @override
  Widget build(BuildContext context) {
    final s = SocialStrings.of(context);
    final ds = DuelStrings.of(context);
    final duel = ref.watch(myDuelProvider).asData?.value;
    final now = widget.now ?? DateTime.now();
    final Widget card;
    if (duel == null) {
      card = _DuelIdle(busy: _busy, onCreate: _create, onJoin: _join);
    } else {
      final rows = ref.watch(groupBoardProvider(duel.id)).asData?.value ?? const <GroupMemberStats>[];
      final board = rows.map(DuelMember.from).toList();
      card = AppCard(
        tone: CardTone.accent,
        header: duel.name.isEmpty || duel.name == s.duelDefaultName ? s.duel : duel.name,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MembersPill(text: ds.members(board.length, duel.maxMembers)),
            const SizedBox(width: 8),
            _CodePill(code: duel.code),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (board.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: RiderLine(s.duelWaiting))
            else
              for (final (i, m) in board.indexed) ...[
                if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Hairline()),
                DuelRow(member: m, leader: i == 0 && board.length > 1, own: m.userId == widget.ownUserId, now: now),
              ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: s.duelShare, glyph: Glyph.share, height: 48, onPressed: _busy ? null : () => _share(duel))),
                const SizedBox(width: 10),
                SecondaryButton(label: s.duelLeave, height: 48, danger: true, onPressed: _busy ? null : () => _leave(duel)),
              ],
            ),
          ],
        ),
      );
    }
    if (!widget.showHistory) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        DuelHistoryList(ownUserId: widget.ownUserId, now: now),
      ],
    );
  }
}

/// The share text of a running duel.
class DuelCardShare {
  const DuelCardShare._();

  /// 'Duell in SlopeTrack: Code KMJ4F2. … https://…/d/?c=KMJ4F2' — the
  /// invite link from SOC-DEEPLINK so a tap lands in the app.
  static String text(SocialStrings s, String code) => '${s.duelShareText(code)} ${InviteLinks.share(InviteKind.duel, code)}';
}

class _DuelIdle extends StatelessWidget {
  const _DuelIdle({required this.busy, required this.onCreate, required this.onJoin});
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final s = SocialStrings.of(context);
    return AppCard(
      header: s.duel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RiderLine(s.duelIdleLine),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: PrimaryButton(label: s.duelStart, height: 52, glow: false, onPressed: busy ? null : onCreate)),
              const SizedBox(width: 10),
              Expanded(child: SecondaryButton(label: s.duelJoin, height: 52, onPressed: busy ? null : onJoin)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.glassFill, borderRadius: BorderRadius.circular(Tokens.rPill), border: Border.all(color: c.hairline, width: c.hairlineWidth)),
      child: child,
    );
  }
}

class _CodePill extends StatelessWidget {
  const _CodePill({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _Pill(child: Text(code, style: AppText.numXs(c.textPrimary).copyWith(fontSize: 13, letterSpacing: 1.2)));
  }
}

/// '2 / 3' — members over capacity.
class _MembersPill extends StatelessWidget {
  const _MembersPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _Pill(child: Text(text, style: AppText.numXs(c.textSecondary).copyWith(fontSize: 12)));
  }
}

/// 6 pt ice dot — the only thing that says 'live' (DESIGN.md: ice for live).
class LiveDot extends StatelessWidget {
  const LiveDot({super.key, this.size = 6});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(width: size, height: size, decoration: BoxDecoration(color: c.ice, shape: BoxShape.circle));
  }
}

/// One member: avatar, name, Abfahrten caption (plus 'live · vor 2 min' with
/// an ice dot while the rider is on the slope), Höhenmeter right.
class DuelRow extends StatelessWidget {
  const DuelRow({super.key, required this.member, required this.leader, required this.own, required this.now});
  final DuelMember member;
  final bool leader;
  final bool own;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final ds = DuelStrings.of(context);
    final l = AppLocale.of(context).code;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          AvatarCircle(name: member.displayName, size: 32, ring: leader, accent: leader, avatarUrl: member.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(own ? s.you : member.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyText(c.textPrimary, size: 16, weight: own ? FontWeight.w700 : FontWeight.w500)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${member.runCount} ${s.metric(SocialMetric.runCount)} · ${Fmt.kmh(member.maxSpeedMs, locale: l)} km/h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(c.textSecondary, size: 12),
                      ),
                    ),
                    if (member.isLive) ...[
                      const SizedBox(width: 8),
                      const LiveDot(),
                      const SizedBox(width: 4),
                      Text(ds.liveLine(member.minutesAgo(now.millisecondsSinceEpoch)), maxLines: 1, style: AppText.caption(c.ice, size: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(Fmt.metres(member.dropM, locale: l), style: AppText.numS(leader ? c.accent : c.textPrimary)),
              const SizedBox(width: 4),
              Text(s.unitHm, style: AppText.unit(c.textTertiary, size: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 'Duell starten' sheet — optional name, returns the typed name ('' for the
/// default).
class DuelCreateSheet extends StatefulWidget {
  const DuelCreateSheet({super.key});
  @override
  State<DuelCreateSheet> createState() => _DuelCreateSheetState();
}

class _DuelCreateSheetState extends State<DuelCreateSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ds = DuelStrings.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RiderLine(ds.createLine),
          const SizedBox(height: 16),
          Text(ds.nameLabel, style: AppText.label(c.textTertiary)),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: ShapeDecoration(color: c.surfaceRaised, shape: Squircle.border(Tokens.r14, side: c.hairline, width: c.hairlineWidth)),
            child: Center(
              child: TextField(
                key: const ValueKey('duel-name-field'),
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                maxLength: 40,
                onSubmitted: (_) => _submit(),
                cursorColor: c.accent,
                style: AppText.bodyText(c.textPrimary, size: 16),
                decoration: InputDecoration.collapsed(hintText: ds.nameHint, hintStyle: AppText.bodyText(c.textTertiary, size: 15)).copyWith(counterText: ''),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(key: const ValueKey('duel-create-button'), label: ds.createAction, height: 52, glow: false, onPressed: _submit),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 'Code eingeben' sheet — six characters, returns the raw input.
class _JoinSheet extends StatefulWidget {
  const _JoinSheet();
  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: ShapeDecoration(color: c.surfaceRaised, shape: Squircle.border(Tokens.r14, side: c.hairline, width: c.hairlineWidth)),
            child: Center(
              child: TextField(
                key: const ValueKey('duel-code-field'),
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                cursorColor: c.accent,
                style: AppText.numS(c.textPrimary).copyWith(letterSpacing: 3),
                decoration: InputDecoration.collapsed(hintText: s.duelCodeHint, hintStyle: AppText.bodyText(c.textTertiary, size: 15)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: s.duelJoin, height: 52, glow: false, onPressed: _submit),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
