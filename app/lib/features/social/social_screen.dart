import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/sync/auth_service.dart';
import '../../data/sync/sync_service.dart';
import '../account/account_providers.dart';
import '../achievements/ui/ui.dart';
import 'challenge/challenge.dart';
import 'country_card.dart';
import 'duel_card.dart';
import 'friends/friends_sheet.dart';
import 'friends/friends_strings.dart';
import 'group_providers.dart';
import 'leaderboard_providers.dart';
import 'leaderboard_view.dart';
import 'social_api.dart';
import 'social_controls.dart';
import 'social_models.dart';
import 'social_strings.dart';

/// Tab 3 — the competition core (docs/DESIGN.md §5 "Rangliste",
/// docs/ONBOARDING-SOCIAL.md): Tagesduell, Wochen-Challenge and the
/// Rangliste with podium, rows and the own row pinned at the bottom.
///
/// Works signed out, opted out and without a backend: every one of those
/// states is a Rider card with one line and one action.
///
/// Scope row: 'Freunde' ranks accepted friends + self (RPC `friends_board`),
/// 'Mein Land' the own team country, 'Gebiet' one resort, 'Alle' everyone;
/// the Länder card below the board sums points per country.
///
/// Refresh: every board provider is dropped when a sync finished pushing
/// days, when the tab is re-entered after [staleAfter], on pull-to-refresh
/// and on 'Erneut versuchen'.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key, this.onOpenAccount, this.now});

  /// Opens the Konto sheet (WP-15). Falls back to a toast when the lead has
  /// not wired it yet.
  final VoidCallback? onOpenAccount;

  /// Injectable clock — the season/month/week key and 'Noch 3 Tage'.
  final DateTime? now;

  /// Re-entering the tab after this long refetches the boards.
  static const Duration staleAfter = Duration(minutes: 5);

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> with WidgetsBindingObserver {
  LeaderboardPeriod _period = LeaderboardPeriod.season;
  SocialMetric _metric = SocialMetric.dropM;
  String? _resortId;
  bool _resortTouched = false;

  /// null until the user taps a scope chip — then the default below applies.
  LeaderboardScope? _scope;

  /// Rows skipped at the top of the board ('Zu mir springen'); 0 = podium view.
  int _offset = 0;

  /// Wall-clock ms of the last refresh, for the tab re-entry rule.
  int? _lastRefreshMs;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastRefreshMs = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshIfStale();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfStale();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Visible again (IndexedStack tab or foreground) after [SocialScreen.staleAfter].
  void _refreshIfStale() {
    if (!TickerMode.valuesOf(context).enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastRefreshMs;
    if (last != null && now - last > SocialScreen.staleAfter.inMilliseconds) _refresh();
  }

  void _refresh() {
    _lastRefreshMs = DateTime.now().millisecondsSinceEpoch;
    refreshBoards(ref);
    ref.invalidate(myDuelProvider);
    ref.invalidate(openChallengesProvider);
  }

  /// Pull-to-refresh: drop the caches and wait for the board to come back.
  Future<void> _pullRefresh(LeaderboardQuery query) async {
    _refresh();
    try {
      await ref.read(boardProvider(query).future);
    } catch (_) {
      // The board renders the failure itself.
    }
  }

  /// A push finished (outbox drained) or a sync run ended — the server has
  /// new days, so the boards are stale.
  void _onSync(AsyncValue<SyncStatus>? previous, AsyncValue<SyncStatus> next) {
    final prev = previous?.asData?.value;
    final cur = next.asData?.value;
    if (prev == null || cur == null) return;
    final drained = prev.pending > 0 && cur.pending == 0 && cur.state != SyncState.syncing;
    final finished = prev.state == SyncState.syncing && cur.state == SyncState.idle;
    if (drained || finished) _refresh();
  }

  void _openAccount() {
    final open = widget.onOpenAccount;
    if (open != null) {
      open();
      return;
    }
    showToast(context, SocialStrings.of(context).signInFirst);
  }

  Future<void> _optIn(String? userId) async {
    await optIntoLeaderboards(ref, userId: userId);
    if (mounted) showToast(context, SocialStrings.of(context).optedIn);
  }

  void _invite() => unawaited(FriendsSheet.show(context));

  void _select(VoidCallback change) => setState(() {
        _offset = 0;
        change();
      });

  @override
  Widget build(BuildContext context) {
    final s = SocialStrings.of(context);
    final api = ref.watch(socialApiProvider);
    final auth = ref.watch(authStateProvider);
    final user = auth.asData?.value;
    final userId = user?.id ?? api?.userId;
    final resorts = ref.watch(resortRepositoryProvider).asData?.value;
    final settings = ref.watch(settingsProvider);
    final homeResortId = settings.lastResortId;
    final countryCode = settings.countryCode;
    // Default scope: the home resort when known, else the own team, else all.
    final scope = _scope ??
        (homeResortId != null
            ? LeaderboardScope.resort
            : countryCode != null
                ? LeaderboardScope.country
                : LeaderboardScope.all);
    final chosenResort = _resortTouched ? _resortId : homeResortId;
    final resortId = scope == LeaderboardScope.resort ? (chosenResort ?? resorts?.all.firstOrNull?.id) : null;
    final resortName = resortId == null ? null : resorts?.byId(resortId)?.name;
    final query = LeaderboardQuery.at(
      _now,
      period: _period,
      resortId: resortId,
      countryCode: scope == LeaderboardScope.country ? countryCode : null,
      metric: _metric,
      friends: scope == LeaderboardScope.friends,
      offset: scope == LeaderboardScope.friends ? 0 : _offset,
    );
    final where = switch (scope) {
      LeaderboardScope.friends => s.friends,
      LeaderboardScope.country => s.countryName(countryCode),
      LeaderboardScope.resort => resortName,
      LeaderboardScope.all => null,
    };
    final signedIn = api != null && user != null;
    // Only with a backend: the sync status provider builds the SyncService.
    if (signedIn) ref.listen<AsyncValue<SyncStatus>>(accountSyncStatusProvider, _onSync);

    final Widget body;
    if (api == null) {
      body = _Offline(onRetry: _refresh);
    } else if (user == null) {
      body = auth.isLoading
          ? const BoardSkeleton()
          : SocialStateBlock(
              pose: 'point',
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
        now: _now,
        resorts: resorts,
        period: _period,
        metric: _metric,
        scope: scope,
        countryCode: countryCode,
        onPeriod: (p) => _select(() => _period = p),
        onMetric: (m) => _select(() => _metric = m),
        onScope: (sc) => _select(() => _scope = sc),
        onResort: (id) => _select(() {
          _resortTouched = true;
          _resortId = id;
        }),
        onOptIn: () => _optIn(userId),
        onRetry: _refresh,
        onInvite: _invite,
        onTop: _offset == 0 ? null : () => setState(() => _offset = 0),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                if (signedIn) CupertinoSliverRefreshControl(onRefresh: () => _pullRefresh(query)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, 140),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ScreenHeader(
                        title: s.title,
                        caption: s.caption(_period, query.seasonKey, where),
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                      ),
                      // Level · Punkte · Streak · Medaillen (docs/GAMIFICATION.md §5)
                      const AchievementsHeader(padding: EdgeInsets.zero),
                      const SizedBox(height: Tokens.cardGap),
                      body,
                    ]),
                  ),
                ),
              ],
            ),
            if (signedIn)
              _PinnedOwnRow(
                query: query,
                userId: userId,
                userName: user.displayName,
                onJump: (rank) => setState(() => _offset = query.offsetAround(rank)),
                onTop: _offset == 0 ? null : () => setState(() => _offset = 0),
              ),
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
    required this.now,
    required this.resorts,
    required this.period,
    required this.metric,
    required this.scope,
    required this.countryCode,
    required this.onPeriod,
    required this.onMetric,
    required this.onScope,
    required this.onResort,
    required this.onOptIn,
    required this.onRetry,
    required this.onInvite,
    required this.onTop,
  });

  final LeaderboardQuery query;
  final String? resortId;
  final String? resortName;
  final String? userId;
  final DateTime now;
  final ResortRepository? resorts;
  final LeaderboardPeriod period;
  final SocialMetric metric;
  final LeaderboardScope scope;

  /// `Settings.countryCode`; null hides the 'Mein Land' chip.
  final String? countryCode;
  final ValueChanged<LeaderboardPeriod> onPeriod;
  final ValueChanged<SocialMetric> onMetric;
  final ValueChanged<LeaderboardScope> onScope;
  final ValueChanged<String?> onResort;
  final VoidCallback onOptIn;
  final VoidCallback onRetry;
  final VoidCallback onInvite;

  /// Non-null while the board shows a window below the top.
  final VoidCallback? onTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SocialStrings.of(context);
    final optedIn = ref.watch(shareLeaderboardsProvider).asData?.value;
    final challenges = ref.watch(openChallengesProvider).asData?.value ?? const <Challenge>[];
    final challenge = currentChallenge(challenges, now);
    final options = _resortOptions();
    final selectedResort = options.indexWhere((o) => o.$1 == resortId);
    final scopes = [
      LeaderboardScope.friends,
      if (countryCode != null) LeaderboardScope.country,
      LeaderboardScope.resort,
      LeaderboardScope.all,
    ];
    // Friends see each other by consent — the opt-in gate is for the public boards.
    final gated = optedIn == false && scope != LeaderboardScope.friends;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // resortId null: a duel is not bound to a Gebiet, the filter above is
        // informational only (docs/BACKLOG.md SOC-RANGLISTE 7).
        DuelCard(resortId: null, ownUserId: userId),
        if (challenge != null) ...[const SizedBox(height: Tokens.cardGap), ChallengeCard(challenge: challenge, now: now)],
        const SizedBox(height: Tokens.sectionGap),
        SocialSegmentTabs(
          labels: s.periods,
          index: LeaderboardPeriod.values.indexOf(period),
          onSelect: (i) => onPeriod(LeaderboardPeriod.values[i]),
        ),
        const SizedBox(height: 14),
        SocialChipRow(
          labels: [for (final sc in scopes) s.scope(sc, countryCode: countryCode)],
          selected: scopes.indexOf(scope),
          onSelect: (i) => onScope(scopes[i]),
        ),
        if (scope == LeaderboardScope.resort && options.isNotEmpty) ...[
          const SizedBox(height: 10),
          SocialChipRow(
            labels: [for (final o in options) o.$2],
            selected: selectedResort < 0 ? 0 : selectedResort,
            onSelect: (i) => onResort(options[i].$1),
          ),
        ],
        const SizedBox(height: 10),
        SocialChipRow(
          labels: [for (final m in SocialMetric.leaderboard) s.metric(m)],
          selected: SocialMetric.leaderboard.indexOf(metric),
          onSelect: (i) => onMetric(SocialMetric.leaderboard[i]),
        ),
        const SizedBox(height: 16),
        if (gated)
          SocialStateBlock(
            pose: 'look',
            headline: s.optInHeadline,
            line: s.optInLine,
            actionLabel: s.optInAction,
            onAction: onOptIn,
          )
        else
          _Board(query: query, userId: userId, resortName: resortName, onRetry: onRetry, onInvite: onInvite, onTop: onTop),
        const SizedBox(height: Tokens.sectionGap),
        CountryBoardCard(seasonKey: query.wireKey, period: period, ownCountryCode: countryCode),
      ],
    );
  }

  /// The home resort first, then the rest of the bundled list.
  List<(String?, String)> _resortOptions() {
    final all = resorts?.all ?? const <Resort>[];
    final home = resortId == null ? null : all.where((r) => r.id == resortId).firstOrNull;
    return <(String?, String)>[
      if (home != null) (home.id, home.name),
      for (final r in all)
        if (r.id != home?.id) (r.id, r.name),
    ];
  }
}

/// Podium + rows, or the offline / error / empty state.
class _Board extends ConsumerWidget {
  const _Board({required this.query, required this.userId, required this.resortName, required this.onRetry, required this.onInvite, required this.onTop});

  final LeaderboardQuery query;
  final String? userId;
  final String? resortName;
  final VoidCallback onRetry;
  final VoidCallback onInvite;
  final VoidCallback? onTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SocialStrings.of(context);
    final board = ref.watch(boardProvider(query));
    return board.when(
      loading: () => const BoardSkeleton(),
      error: (e, _) {
        final kind = e is SocialError ? e.kind : SocialErrorKind.failed;
        if (kind == SocialErrorKind.offline) return _Offline(onRetry: onRetry);
        return SocialStateBlock(pose: 'lean', headline: s.errorHeadline, line: s.errorLine(kind), actionLabel: s.retry, onAction: onRetry);
      },
      data: (entries) {
        // The friends board always contains the caller — alone means empty.
        final friendsOnly = query.friends && entries.every((e) => e.userId == userId);
        if (entries.isEmpty || friendsOnly) {
          final f = FriendsStrings.of(context);
          return SocialStateBlock(
            pose: 'carve',
            headline: query.friends ? f.boardEmptyHeadline : s.emptyHeadline(resortName),
            line: query.friends ? f.boardEmptyLine : s.emptyLine,
            actionLabel: s.invite,
            onAction: onInvite,
          );
        }
        final windowed = query.offset > 0;
        final podium = windowed ? const <LeaderboardEntry>[] : entries.take(3).toList();
        final rest = windowed ? entries : (entries.length > 3 ? entries.sublist(3) : const <LeaderboardEntry>[]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (podium.isNotEmpty) LeaderboardPodium(entries: podium, metric: query.metric, ownUserId: userId),
            if (windowed && onTop != null)
              Align(
                alignment: Alignment.centerLeft,
                child: SocialFilterChip(label: s.backToTop, selected: false, onTap: onTop),
              ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: Tokens.cardGap),
              // Below the top the leader's value is unknown — no delta caption.
              LeaderboardRows(entries: rest, metric: query.metric, ownUserId: userId, leaderValue: windowed ? null : entries.first.value),
            ],
          ],
        );
      },
    );
  }
}

/// Three 64 pt placeholder rows at 6 % — never a Material spinner. Shown while
/// the board loads and while the auth state is still unknown.
class BoardSkeleton extends StatelessWidget {
  const BoardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      key: const ValueKey('board-skeleton'),
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
      pose: 'lean',
      headline: s.offlineHeadline,
      line: s.offlineLine,
      actionLabel: s.retry,
      onAction: onRetry,
    );
  }
}

/// 'Du · Platz 14 von 250 · 12.480 hm' above the tab bar — from the fetched
/// slice when the user is in it, else from `my_rank`; 'Du bist noch nicht
/// gewertet' when the server has no row. Hidden only while opted out, while
/// the rank is still loading or when the board itself failed.
class _PinnedOwnRow extends ConsumerWidget {
  const _PinnedOwnRow({required this.query, required this.userId, required this.userName, required this.onJump, required this.onTop});

  final LeaderboardQuery query;
  final String? userId;
  final String userName;
  final ValueChanged<int> onJump;
  final VoidCallback? onTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optedOut = ref.watch(shareLeaderboardsProvider).asData?.value == false;
    if (optedOut && !query.friends) return const SizedBox.shrink();
    final board = ref.watch(boardProvider(query));
    if (board.hasError) return const SizedBox.shrink();
    final entries = board.asData?.value ?? const <LeaderboardEntry>[];
    final inSlice = myRankOf(entries, userId);
    final MyRank? rank;
    if (inSlice != null) {
      rank = inSlice;
    } else {
      final remote = ref.watch(myRankProvider(query));
      if (!remote.hasValue) return const SizedBox.shrink();
      rank = remote.value;
    }
    final r = rank;
    // Not in the slice and not ranked server-side: nothing to pin.
    if (r == null) return const SizedBox.shrink();
    final canJump = inSlice == null && !query.friends && !query.covers(r.rank);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: OwnRankStrip(
        rank: r,
        metric: query.metric,
        name: userName,
        bottomPadding: 56 + MediaQuery.paddingOf(context).bottom,
        onJump: canJump ? () => onJump(r.rank) : null,
        onTop: onTop,
      ),
    );
  }
}
