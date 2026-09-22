import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../onboarding/mascot_hero.dart';
import 'group_providers.dart';
import 'social_api.dart';
import 'social_controls.dart';
import 'social_models.dart';
import 'social_strings.dart';

/// Tagesduell — the private race of the day (docs/ONBOARDING-SOCIAL.md).
///
/// Sits on top of the Rangliste while a duel is running: every member with
/// live Höhenmeter, the leader in champagne, share / leave. Without a duel it
/// offers 'Duell starten' and 'Code eingeben'.
///
/// The board is refetched every [duelPollIntervalProvider] while the tab is
/// visible and the app is in the foreground; override the provider with `null`
/// to switch polling off (widget tests).
class DuelCard extends ConsumerStatefulWidget {
  const DuelCard({super.key, this.resortId, this.ownUserId});

  final String? resortId;
  final String? ownUserId;

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

  Future<void> _run(Future<void> Function(SocialApi api) op) async {
    final api = ref.read(socialApiProvider);
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

  Future<void> _create() => _run((api) async {
        final s = SocialStrings.of(context);
        final group = await api.createDuel(name: s.duelDefaultName, day: today(), resortId: widget.resortId);
        ref.invalidate(myDuelProvider);
        ref.invalidate(groupBoardProvider(group.id));
        if (mounted) showToast(context, s.duelCreated);
      });

  Future<void> _join() async {
    final s = SocialStrings.of(context);
    final code = await AppSheet.show<String>(context, title: s.duelJoin, builder: (_) => const _JoinSheet());
    if (code == null || !mounted) return;
    await _run((api) async {
      final group = await api.joinDuel(code);
      ref.invalidate(myDuelProvider);
      ref.invalidate(groupBoardProvider(group.id));
      if (mounted) showToast(context, s.duelJoined);
    });
  }

  Future<void> _leave(DuelGroup duel) => _run((api) async {
        final s = SocialStrings.of(context);
        await api.leaveDuel(duel.id);
        ref.invalidate(myDuelProvider);
        if (mounted) showToast(context, s.duelLeft);
      });

  Future<void> _share(DuelGroup duel) async {
    final s = SocialStrings.of(context);
    await SharePlus.instance.share(ShareParams(text: s.duelShareText(duel.code), subject: s.duel));
  }

  @override
  Widget build(BuildContext context) {
    final s = SocialStrings.of(context);
    final duel = ref.watch(myDuelProvider).asData?.value;
    if (duel == null) return _DuelIdle(busy: _busy, onCreate: _create, onJoin: _join);
    final board = ref.watch(groupBoardProvider(duel.id)).asData?.value ?? const <GroupMemberStats>[];
    return AppCard(
      tone: CardTone.accent,
      header: s.duel,
      trailing: _CodePill(code: duel.code),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (board.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: MascotLine(s.duelWaiting))
          else
            for (final (i, m) in board.indexed) ...[
              if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Hairline()),
              _DuelRow(member: m, leader: i == 0 && board.length > 1, own: m.userId == widget.ownUserId),
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
          MascotLine(s.duelIdleLine),
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

class _CodePill extends StatelessWidget {
  const _CodePill({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.glassFill, borderRadius: BorderRadius.circular(Tokens.rPill), border: Border.all(color: c.hairline, width: c.hairlineWidth)),
      child: Text(code, style: AppText.numXs(c.textPrimary).copyWith(fontSize: 13, letterSpacing: 1.2)),
    );
  }
}

/// One member: avatar, name, Abfahrten caption, Höhenmeter right.
class _DuelRow extends StatelessWidget {
  const _DuelRow({required this.member, required this.leader, required this.own});
  final GroupMemberStats member;
  final bool leader;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final l = AppLocale.of(context).code;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          AvatarCircle(name: member.displayName, size: 32, ring: leader, accent: leader),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(own ? s.you : member.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyText(c.textPrimary, size: 16, weight: own ? FontWeight.w700 : FontWeight.w500)),
                Text(
                  '${member.runCount} ${s.metric(SocialMetric.runCount)} · ${Fmt.kmh(member.maxSpeedMs, locale: l)} km/h',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(c.textSecondary, size: 12),
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
