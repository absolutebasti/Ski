import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../duel/duel.dart';
import '../../../app/l10n/app_locale.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import '../../../data/resorts/resort_repository.dart';
import '../../achievements/achievements_engine.dart';
import '../../achievements/achievements_strings.dart';
import '../../achievements/medal_catalog.dart';
import '../country_card.dart';
import '../leaderboard_providers.dart';
import '../moderation/moderation_api.dart';
import '../moderation/moderation_providers.dart';
import '../moderation/moderation_strings.dart';
import '../social_api.dart';
import '../social_controls.dart';
import '../social_models.dart';
import '../social_strings.dart';
import 'rider_models.dart';
import 'rider_providers.dart';
import 'rider_strings.dart';

/// The profile behind a leaderboard row (SOC-RIDER): avatar, name, team flag,
/// 'LEVEL n · TITLE', the season's four numerals, medal count and the actions.
///
/// [show] is the only public entry; leaderboard rows, podium columns, duel and
/// challenge boards call it with the row's user id.
class RiderSheet {
  const RiderSheet._();

  static Future<void> show(BuildContext context, String userId) => AppSheet.show<void>(
        context,
        title: RiderStrings.of(context).title,
        builder: (_) => RiderSheetBody(userId: userId),
      );
}

/// Body of the sheet; exposed for tests, use [RiderSheet.show] in the app.
class RiderSheetBody extends ConsumerStatefulWidget {
  const RiderSheetBody({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<RiderSheetBody> createState() => _RiderSheetBodyState();
}

class _RiderSheetBodyState extends ConsumerState<RiderSheetBody> {
  bool _busy = false;

  void _retry() => ref.invalidate(riderProfileProvider(widget.userId));

  /// 'Herausfordern': today's duel (reused when one exists, else created with
  /// resortId null — the Gebiet is informational only) and its code go to the
  /// share sheet addressed to the rider.
  Future<void> _challenge(RiderProfile rider) async {
    final api = ref.read(socialApiProvider);
    final s = RiderStrings.of(context);
    final ss = SocialStrings.of(context);
    if (api == null) {
      showToast(context, ss.error(SocialErrorKind.offline));
      return;
    }
    if (api.userId == null) {
      showToast(context, ss.signInFirst);
      return;
    }
    setState(() => _busy = true);
    try {
      final duelApi = ref.read(duelApiProvider);
      final duel = await api.myDuel(today()) ??
          (duelApi != null
              ? await duelApi.createDuel(name: ss.duelDefaultName, day: today(), tz: ref.read(deviceTimeZoneProvider), resortId: null)
              : await api.createDuel(name: ss.duelDefaultName, day: today(), resortId: null));
      invalidateDuels(ref);
      ref.invalidate(groupBoardProvider(duel.id));
      if (mounted) showToast(context, s.challengeToast(rider.displayName));
      await ref.read(riderShareProvider)(text: s.challengeText(rider.displayName, duel.code), subject: s.challengeSubject);
    } on SocialError catch (e) {
      if (mounted) showToast(context, ss.error(e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 'Blockierung aufheben' (SOC-MODERATION): the service drops the block and
  /// refreshes every board; the sheet leaves its blocked state via
  /// [blockedIdsProvider].
  Future<void> _unblock(RiderProfile rider) async {
    final s = ModerationStrings.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(moderationServiceProvider).unblock(rider.userId);
      if (mounted) showToast(context, s.unblocked);
    } on ModerationError catch (e) {
      if (mounted) showToast(context, s.error(e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(RiderAction action, RiderProfile rider) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(context, rider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = RiderStrings.of(context);
    final profile = ref.watch(riderProfileProvider(widget.userId));
    final ownId = ref.watch(socialUserIdProvider);
    final actions = ref.watch(riderActionsProvider);
    return profile.when(
      loading: () => const RiderSkeleton(),
      error: (e, _) {
        final kind = e is SocialError ? e.kind : SocialErrorKind.failed;
        return switch (kind) {
          SocialErrorKind.offline => SocialStateBlock(pose: 'lean', headline: s.offlineHeadline, line: s.offlineLine, actionLabel: s.retry, onAction: _retry),
          SocialErrorKind.notSignedIn => SocialStateBlock(pose: 'point', headline: s.signInHeadline, line: s.signInLine),
          _ => SocialStateBlock(pose: 'lean', headline: s.errorHeadline, line: s.errorLine, actionLabel: s.retry, onAction: _retry),
        };
      },
      data: (rider) {
        if (rider == null) return SocialStateBlock(pose: 'look', headline: s.privateHeadline, line: s.privateLine);
        final self = rider.userId == ownId;
        // SOC-MODERATION: a rider the user blocked shows 'Blockiert' + undo
        // instead of challenge / friend / block.
        final blocked = !self && (ref.watch(blockedIdsProvider).asData?.value.contains(rider.userId) ?? false);
        return _Profile(
          rider: rider,
          busy: _busy,
          blocked: blocked,
          onUnblock: blocked ? () => _unblock(rider) : null,
          onChallenge: self || blocked ? null : () => _challenge(rider),
          // ---- actions slot ------------------------------------------------
          // Filled by later packages via [riderActionsProvider]:
          //   SOC-FRIENDS / SOC-RANGLISTE → addFriend ('Freund hinzufügen')
          //   SOC-MODERATION            → report ('Melden'), block ('Blockieren')
          // Buttons render only when a handler is set; never on the own profile.
          onAddFriend: self || blocked || actions.addFriend == null ? null : () => _run(actions.addFriend!, rider),
          onReport: self || actions.report == null ? null : () => _run(actions.report!, rider),
          onBlock: self || blocked || actions.block == null ? null : () => _run(actions.block!, rider),
          // -------------------------------------------------------------------
        );
      },
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({
    required this.rider,
    required this.busy,
    this.blocked = false,
    this.onUnblock,
    required this.onChallenge,
    required this.onAddFriend,
    required this.onReport,
    required this.onBlock,
  });

  final RiderProfile rider;
  final bool busy;

  /// The user blocked this rider: chip 'Blockiert' + 'Blockierung aufheben'.
  final bool blocked;
  final VoidCallback? onUnblock;
  final VoidCallback? onChallenge;
  final VoidCallback? onAddFriend;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = RiderStrings.of(context);
    final ss = SocialStrings.of(context);
    final a = AchievementsStrings.of(context);
    final level = levelFor(rider.lifetimeSkiDistanceM);
    final medals = riderMedalCount(rider);
    final resortName = rider.homeResortId == null ? null : ref.watch(resortRepositoryProvider).asData?.value.byId(rider.homeResortId!)?.name;
    final country = ss.countryName(rider.countryCode);
    final where = [if (country.isNotEmpty) country, ?resortName].join(' · ');
    final ms = ModerationStrings.of(context);
    final hasActions = blocked || onChallenge != null || onAddFriend != null || onReport != null || onBlock != null;

    return Semantics(
      label: s.profileOf(rider.displayName),
      container: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- identity -------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AvatarCircle(name: rider.displayName, size: 64, avatarUrl: rider.avatarUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(rider.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headline(c.textPrimary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (rider.countryCode != null) ...[CountryFlag(countryCode: rider.countryCode!, size: 22), const SizedBox(width: 8)],
                          Expanded(child: Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(c.textSecondary))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(s.lastDay(rider.lastDayMs), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(c.textTertiary, size: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(a.levelLine(level).overline, style: AppText.label(c.textSecondary)),
            const SizedBox(height: Tokens.sectionGap),

            // ---- season numerals ------------------------------------------
            Text(s.season(rider.seasonKey).overline, style: AppText.label(c.textTertiary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatTile(label: s.vertical, value: Fmt.metres(rider.seasonDropM, locale: l.code), unit: s.unitHm)),
                const SizedBox(width: Tokens.cardGap),
                Expanded(child: StatTile(label: s.distance, value: Fmt.km(rider.seasonSkiDistanceM, decimals: 0, locale: l.code), unit: s.unitKm)),
              ],
            ),
            const SizedBox(height: Tokens.cardGap),
            Row(
              children: [
                Expanded(child: StatTile(label: s.runs, value: '${rider.seasonRunCount}')),
                const SizedBox(width: Tokens.cardGap),
                Expanded(child: StatTile(label: s.days, value: '${rider.seasonDayCount}')),
              ],
            ),
            const SizedBox(height: 16),

            // ---- lifetime chips -------------------------------------------
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StateChip(text: s.medals(medals, medalCatalog.length), tone: medals > 0 ? ChipTone.accent : ChipTone.neutral),
                StateChip(text: '${Fmt.metres(rider.lifetimePoints, locale: l.code)} ${s.unitPoints}'),
                StateChip(text: s.lifetimeKm(Fmt.km(rider.lifetimeSkiDistanceM, decimals: 0, locale: l.code))),
              ],
            ),

            // ---- actions --------------------------------------------------
            if (hasActions) const SizedBox(height: Tokens.sectionGap),
            if (blocked) ...[
              Row(children: [StateChip(key: const ValueKey('rider-blocked'), text: ms.blocked, tone: ChipTone.danger)]),
              const SizedBox(height: 10),
              SecondaryButton(key: const ValueKey('rider-unblock'), label: ms.unblock, height: 48, onPressed: busy ? null : onUnblock),
            ],
            if (onChallenge != null) ...[
              PrimaryButton(label: s.challenge, height: 52, glow: false, glyph: Glyph.podium, onPressed: busy ? null : onChallenge),
              const SizedBox(height: 8),
              Text(s.challengeCaption, key: const ValueKey('rider-challenge-caption'), textAlign: TextAlign.center, style: AppText.caption(c.textTertiary, size: 12)),
            ],
            if (onAddFriend != null) ...[
              const SizedBox(height: 10),
              SecondaryButton(label: s.addFriend, height: 48, onPressed: busy ? null : onAddFriend),
            ],
            if (onReport != null || onBlock != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onReport != null) Expanded(child: SecondaryButton(label: s.report, height: 44, onPressed: busy ? null : onReport)),
                  if (onReport != null && onBlock != null) const SizedBox(width: 10),
                  if (onBlock != null) Expanded(child: SecondaryButton(label: s.block, height: 44, danger: true, onPressed: busy ? null : onBlock)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state: the shape of the profile at 6 % — never a Material spinner.
class RiderSkeleton extends StatelessWidget {
  const RiderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget block(double h, {double? w, double r = Tokens.r14}) => Opacity(
          opacity: 0.06,
          child: Container(width: w, height: h, decoration: ShapeDecoration(color: c.textPrimary, shape: Squircle.plain(r))),
        );
    return Column(
      key: const ValueKey('rider-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Opacity(opacity: 0.06, child: Container(width: 64, height: 64, decoration: BoxDecoration(color: c.textPrimary, shape: BoxShape.circle))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [block(22, w: 160, r: 6), const SizedBox(height: 8), block(14, w: 110, r: 6)])),
          ],
        ),
        const SizedBox(height: Tokens.sectionGap),
        Row(children: [Expanded(child: block(88)), const SizedBox(width: Tokens.cardGap), Expanded(child: block(88))]),
        const SizedBox(height: Tokens.cardGap),
        Row(children: [Expanded(child: block(88)), const SizedBox(width: Tokens.cardGap), Expanded(child: block(88))]),
        const SizedBox(height: 16),
        block(52, r: 26),
      ],
    );
  }
}
