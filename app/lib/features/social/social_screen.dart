import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';
import '../../core/settings.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/sync/auth_service.dart';
import '../../data/sync/sync_service.dart';
import '../account/account_providers.dart';
import '../achievements/ui/ui.dart';
import '../days/resort_picker.dart';
import '../share/share_card_data.dart';
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
/// the Länder card below the board sums points per country. The Gebiet is
/// one chip ('Gebiet: Kitzbühel ›') that opens the resort picker; it starts
/// on the home resort, else the resort of the last local day, and is hidden
/// while neither exists. The header carries the 'Freunde' button (with the
/// pending-request badge) so the friends sheet stays reachable once the
/// board is no longer empty.
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
    final countryCode = ref.watch(settingsProvider.select((st) => st.countryCode));
    final defaultResortId = ref.watch(boardDefaultResortIdProvider);
    // The Gebiet chip needs a resort to name — none known: no Gebiet scope.
    final chosenResort = _resortTouched ? _resortId : defaultResortId;
    final hasResort = chosenResort != null;
    // Default scope: the resort when known, else the own team, else all. A
    // remembered Gebiet choice without a resort (home cleared) falls back too.
    final wanted = _scope;
    final scope = wanted != null && (wanted != LeaderboardScope.resort || hasResort)
        ? wanted
        : hasResort
            ? LeaderboardScope.resort
            : countryCode != null
                ? LeaderboardScope.country
                : LeaderboardScope.all;
    final resortId = scope == LeaderboardScope.resort ? chosenResort : null;
    final resortName = resortId == null ? null : resorts?.byId(resortId)?.name ?? resortId;
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
        hasResort: hasResort,
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
                        trailing: signedIn ? [_FriendsButton(onTap: _invite)] : null,
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
                scopeName: where,
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
    required this.hasResort,
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

  /// False hides the 'Gebiet' chip: no home resort, no local day with one.
  final bool hasResort;

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
    final scopes = [
      LeaderboardScope.friends,
      if (countryCode != null) LeaderboardScope.country,
      if (hasResort) LeaderboardScope.resort,
      LeaderboardScope.all,
    ];
    final name = resortName;
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
        if (scope == LeaderboardScope.resort && name != null) ...[
          const SizedBox(height: 10),
          SocialPickerChip(
            key: const ValueKey('resort-chip'),
            label: s.resortChip(name),
            onTap: () => _pickResort(context),
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

  /// The resort picker of Tage, nearest to the current Gebiet first. Dismiss
  /// and 'Freies Gelände' (no resort) leave the board as it is.
  Future<void> _pickResort(BuildContext context) async {
    final repo = resorts;
    if (repo == null) return;
    final current = resortId == null ? null : repo.byId(resortId!);
    final pick = await ResortPickerSheet.show(context, resorts: repo.all, lat: current?.lat, lon: current?.lon, currentId: resortId);
    final picked = pick?.resort;
    if (picked != null) onResort(picked.id);
  }
}

/// The header action: two-rider glyph + the count of incoming requests.
class _FriendsButton extends ConsumerWidget {
  const _FriendsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(friendsBadgeCountProvider);
    return FriendsHeaderButton(
      key: const ValueKey('friends-button'),
      pending: pending,
      label: SocialStrings.of(context).friendsButton(pending),
      onTap: onTap,
    );
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
/// gewertet' when the board has loaded, the user is opted in and the server
/// has no row. Hidden while opted out, while board or rank are still loading
/// and when either failed. The share glyph builds the rank card.
class _PinnedOwnRow extends ConsumerWidget {
  const _PinnedOwnRow({
    required this.query,
    required this.userId,
    required this.userName,
    required this.scopeName,
    required this.onJump,
    required this.onTop,
  });

  final LeaderboardQuery query;
  final String? userId;
  final String userName;

  /// Resort / country / 'Freunde' for the share card; null = every resort.
  final String? scopeName;
  final ValueChanged<int> onJump;
  final VoidCallback? onTop;

  RankCardData _cardData(BuildContext context, MyRank r) => RankCardData(
        rank: r.rank,
        total: r.total,
        value: r.value,
        metric: shareMetricOf(query.metric),
        seasonKey: query.seasonKey,
        scopeName: scopeName,
        periodLabel: SocialStrings.of(context).sharePeriodLabel(query.period, query.wireKey),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optedIn = ref.watch(shareLeaderboardsProvider).asData?.value;
    // Friends see each other by consent; every other board needs the opt-in.
    if (optedIn != true && !query.friends) return const SizedBox.shrink();
    final board = ref.watch(boardProvider(query));
    if (!board.hasValue || board.hasError) return const SizedBox.shrink();
    final entries = board.asData?.value ?? const <LeaderboardEntry>[];
    final inSlice = myRankOf(entries, userId);
    final MyRank? rank;
    if (inSlice != null) {
      rank = inSlice;
    } else {
      final remote = ref.watch(myRankProvider(query));
      if (!remote.hasValue || remote.hasError) return const SizedBox.shrink();
      rank = remote.value;
    }
    final r = rank;
    final canJump = r != null && inSlice == null && !query.friends && !query.covers(r.rank);
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
        onShare: r == null ? null : () => unawaited(ref.read(rankShareProvider)(context, _cardData(context, r))),
      ),
    );
  }
}
