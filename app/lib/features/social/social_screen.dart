import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/sync/auth_service.dart';
import 'challenge_card.dart';
import 'challenge_providers.dart';
import 'duel_card.dart';
import 'group_providers.dart';
import 'leaderboard_providers.dart';
import 'leaderboard_view.dart';
import 'social_api.dart';
import 'social_controls.dart';
import 'social_models.dart';
import 'social_strings.dart';

/// Tab 3 — the competition core (docs/DESIGN.md §5 "Rangliste",
/// docs/ONBOARDING-SOCIAL.md): Tagesduell, Wochen-Challenge and the
/// Gebiets-Rangliste with podium, rows and the own row pinned at the bottom.
///
/// Works signed out, opted out and without a backend: every one of those
/// states is a Leo card with one line and one action.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key, this.onOpenAccount, this.now});

  /// Opens the Konto sheet (WP-15). Falls back to a toast when the lead has
  /// not wired it yet.
  final VoidCallback? onOpenAccount;

  /// Injectable clock — the season/month/week key and 'Noch 3 Tage'.
  final DateTime? now;

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.season;
  SocialMetric _metric = SocialMetric.dropM;
  String? _resortId;
  bool _resortTouched = false;

  DateTime get _now => widget.now ?? DateTime.now();

  void _openAccount() {
    final open = widget.onOpenAccount;
    if (open != null) {
      open();
      return;
    }
    showToast(context, SocialStrings.of(context).signInFirst);
  }

  void _retry(LeaderboardQuery query) {
    ref.invalidate(leaderboardProvider(query));
    ref.invalidate(shareLeaderboardsProvider);
    ref.invalidate(myDuelProvider);
    ref.invalidate(openChallengesProvider);
  }

  Future<void> _invite() async {
    final s = SocialStrings.of(context);
    await SharePlus.instance.share(ShareParams(text: s.inviteText, subject: s.title));
  }

  @override
  Widget build(BuildContext context) {
    final s = SocialStrings.of(context);
    final api = ref.watch(socialApiProvider);
    final auth = ref.watch(authStateProvider);
    final user = auth.asData?.value;
    final userId = user?.id ?? api?.userId;
    final resorts = ref.watch(resortRepositoryProvider).asData?.value;
    final homeResortId = ref.watch(settingsProvider).lastResortId;
    final resortId = _resortTouched ? _resortId : homeResortId;
    final resortName = resortId == null ? null : resorts?.byId(resortId)?.name;
    final query = LeaderboardQuery.at(_now, period: _period, resortId: resortId, metric: _metric);

    final Widget body;
    if (api == null) {
      body = _Offline(onRetry: () => _retry(query));
    } else if (user == null) {
      body = auth.isLoading
          ? const SizedBox.shrink()
          : SocialStateBlock(
              pose: 'wave',
              headline: s.signedOutHeadline,
              line: s.signedOutLine(resortName),
              actionLabel: s.signIn,
              onAction: _openAccount,
            );
    } else {
      body = _SignedIn(
        query: query,
        resortId: resortId,
        resortName: resortName,
        userId: userId,
        userName: user.displayName,
        now: _now,
        resorts: resorts,
        period: _period,
        metric: _metric,
        onPeriod: (p) => setState(() => _period = p),
        onMetric: (m) => setState(() => _metric = m),
        onResort: (id) => setState(() {
          _resortTouched = true;
          _resortId = id;
        }),
        onOpenAccount: _openAccount,
        onRetry: () => _retry(query),
        onInvite: _invite,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, 140),
              children: [
                ScreenHeader(
                  title: s.title,
                  caption: s.caption(_period, query.seasonKey, resortName),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                ),
                body,
              ],
            ),
            if (api != null && user != null) _PinnedOwnRow(query: query, userId: userId, userName: user.displayName),
          ],
        ),
      ),
    );
  }
}

/// Everything below the header once a Konto is signed in.
class _SignedIn extends ConsumerWidget {
  const _SignedIn({
    required this.query,
    required this.resortId,
    required this.resortName,
    required this.userId,
    required this.userName,
    required this.now,
    required this.resorts,
    required this.period,
    required this.metric,
    required this.onPeriod,
    required this.onMetric,
    required this.onResort,
    required this.onOpenAccount,
    required this.onRetry,
    required this.onInvite,
  });

  final LeaderboardQuery query;
  final String? resortId;
  final String? resortName;
  final String? userId;
  final String userName;
  final DateTime now;
  final ResortRepository? resorts;
  final LeaderboardPeriod period;
  final SocialMetric metric;
  final ValueChanged<LeaderboardPeriod> onPeriod;
  final ValueChanged<SocialMetric> onMetric;
  final ValueChanged<String?> onResort;
  final VoidCallback onOpenAccount;
  final VoidCallback onRetry;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SocialStrings.of(context);
    final optedIn = ref.watch(shareLeaderboardsProvider).asData?.value;
    final challenges = ref.watch(openChallengesProvider).asData?.value ?? const <Challenge>[];
    final challenge = currentChallenge(challenges, now);
    final options = _resortOptions(s.allResorts);
    final selectedResort = options.indexWhere((o) => o.$1 == resortId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DuelCard(resortId: resortId, ownUserId: userId),
        if (challenge != null) ...[const SizedBox(height: Tokens.cardGap), ChallengeCard(challenge: challenge, now: now)],
        const SizedBox(height: Tokens.sectionGap),
        SocialSegmentTabs(
          labels: s.periods,
          index: LeaderboardPeriod.values.indexOf(period),
          onSelect: (i) => onPeriod(LeaderboardPeriod.values[i]),
        ),
        const SizedBox(height: 14),
        SocialChipRow(
          labels: [for (final o in options) o.$2],
          selected: selectedResort < 0 ? 0 : selectedResort,
          onSelect: (i) => onResort(options[i].$1),
        ),
        const SizedBox(height: 10),
        SocialChipRow(
          labels: [for (final m in SocialMetric.leaderboard) s.metric(m)],
          selected: SocialMetric.leaderboard.indexOf(metric),
          onSelect: (i) => onMetric(SocialMetric.leaderboard[i]),
        ),
        const SizedBox(height: 16),
        if (optedIn == false)
          SocialStateBlock(
            pose: 'goggles-down',
            headline: s.optInHeadline,
            line: s.optInLine,
            actionLabel: s.optInAction,
            onAction: onOpenAccount,
          )
        else
          _Board(query: query, userId: userId, resortName: resortName, onRetry: onRetry, onInvite: onInvite),
      ],
    );
  }

  /// 'Alle Gebiete', the home resort, then the rest of the bundled list.
  List<(String?, String)> _resortOptions(String allLabel) {
    final all = resorts?.all ?? const <Resort>[];
    final home = resortId == null ? null : all.where((r) => r.id == resortId).firstOrNull;
    return <(String?, String)>[
      (null, allLabel),
      if (home != null) (home.id, home.name),
      for (final r in all)
        if (r.id != home?.id) (r.id, r.name),
    ];
  }
}

/// Podium + rows, or the offline / empty state.
class _Board extends ConsumerWidget {
  const _Board({required this.query, required this.userId, required this.resortName, required this.onRetry, required this.onInvite});

  final LeaderboardQuery query;
  final String? userId;
  final String? resortName;
  final VoidCallback onRetry;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SocialStrings.of(context);
    final board = ref.watch(leaderboardProvider(query));
    return board.when(
      loading: () => const _BoardSkeleton(),
      error: (e, _) => e is SocialError && e.kind != SocialErrorKind.offline
          ? SocialStateBlock(pose: 'think', headline: s.error(e.kind), line: s.offlineLine, actionLabel: s.retry, onAction: onRetry)
          : _Offline(onRetry: onRetry),
      data: (entries) {
        if (entries.isEmpty) {
          return SocialStateBlock(
            pose: 'point',
            headline: s.emptyHeadline(resortName),
            line: s.emptyLine,
            actionLabel: s.invite,
            onAction: onInvite,
          );
        }
        final rest = entries.length > 3 ? entries.sublist(3) : const <LeaderboardEntry>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LeaderboardPodium(entries: entries.take(3).toList(), metric: query.metric, ownUserId: userId),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: Tokens.cardGap),
              LeaderboardRows(entries: rest, metric: query.metric, ownUserId: userId),
            ],
          ],
        );
      },
    );
  }
}

/// Three 64 pt placeholder rows at 6 % — never a Material spinner.
class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: Tokens.cardGap),
          Opacity(
            opacity: 0.06,
            child: Container(
              height: 64,
              decoration: ShapeDecoration(color: c.textPrimary, shape: Squircle.plain(Tokens.r20)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = SocialStrings.of(context);
    return SocialStateBlock(
      pose: 'think',
      headline: s.offlineHeadline,
      line: s.offlineLine,
      actionLabel: s.retry,
      onAction: onRetry,
    );
  }
}

/// 'Du · Platz 14 · 12.480 hm' above the tab bar — only when the user is in
/// the fetched slice.
class _PinnedOwnRow extends ConsumerWidget {
  const _PinnedOwnRow({required this.query, required this.userId, required this.userName});

  final LeaderboardQuery query;
  final String? userId;
  final String userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optedOut = ref.watch(shareLeaderboardsProvider).asData?.value == false;
    final entries = ref.watch(leaderboardProvider(query)).asData?.value ?? const <LeaderboardEntry>[];
    final rank = optedOut ? null : myRankOf(entries, userId);
    if (rank == null) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: OwnRankStrip(rank: rank, metric: query.metric, name: userName, bottomPadding: 56 + MediaQuery.paddingOf(context).bottom),
    );
  }
}
