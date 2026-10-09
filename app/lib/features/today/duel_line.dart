import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../recording/live_state_provider.dart';
import '../social/duel/duel.dart';
import '../social/social_models.dart';
import 'today_strings.dart';
import '../social/rider_name.dart';

/// Where the rider stands in today's Tagesduell, measured against the board.
///
/// [place] counts the members with more vertical than [ownDropM] plus one;
/// [other] is the leader when behind, the runner-up when leading; [gapM] is
/// the distance to [other] (always ≥ 0). `other == null` means alone.
class DuelStanding {
  const DuelStanding({required this.place, required this.other, required this.gapM});
  final int place;
  final GroupMemberStats? other;
  final double gapM;

  bool get leading => place == 1;

  /// Own vertical comes from the live state (fresher than the own board row,
  /// which lags the upload interval); the own row itself is skipped.
  static DuelStanding of(List<GroupMemberStats> board, {required String? ownUserId, required double ownDropM}) {
    final others = board.where((m) => m.userId != ownUserId).toList()..sort((a, b) => b.dropM.compareTo(a.dropM));
    final ahead = others.where((m) => m.dropM > ownDropM).toList();
    if (ahead.isNotEmpty) {
      final leader = ahead.first;
      return DuelStanding(place: ahead.length + 1, other: leader, gapM: leader.dropM - ownDropM);
    }
    final runnerUp = others.firstOrNull;
    return DuelStanding(place: 1, other: runnerUp, gapM: runnerUp == null ? 0 : ownDropM - runnerUp.dropM);
  }
}

/// One caption line under the live status row: 'Duell: Platz 2 · Lena +120 hm'.
/// Nothing without a duel, a board or a signed-in user. The board is refetched
/// every [duelPollIntervalProvider] while this line is on screen (the live
/// face is only mounted while recording, so the timer dies with the day).
class DuelLine extends ConsumerStatefulWidget {
  const DuelLine({super.key});

  @override
  ConsumerState<DuelLine> createState() => _DuelLineState();
}

class _DuelLineState extends ConsumerState<DuelLine> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final interval = ref.read(duelPollIntervalProvider);
    if (interval != null) _timer = Timer.periodic(interval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final duel = ref.read(myDuelProvider).asData?.value;
    if (duel == null) return;
    ref.invalidate(groupBoardProvider(duel.id));
  }

  @override
  Widget build(BuildContext context) {
    final duel = ref.watch(myDuelProvider).asData?.value;
    if (duel == null) return const SizedBox.shrink();
    final board = ref.watch(groupBoardProvider(duel.id)).asData?.value;
    if (board == null || board.isEmpty) return const SizedBox.shrink();
    final ownUserId = ref.watch(duelApiProvider)?.userId;
    if (ownUserId == null) return const SizedBox.shrink();
    final ownDropM = ref.watch(liveStateProvider.select((s) => s.stats.dropM));
    final standing = DuelStanding.of(board, ownUserId: ownUserId, ownDropM: ownDropM);

    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final other = standing.other;
    final hm = Fmt.metres(standing.gapM, locale: l.code);
    final text = other == null
        ? s.duelAlone
        : standing.leading
            ? s.duelAhead(runnerUp: riderName(context, other.displayName), hm: hm)
            : s.duelBehind(place: standing.place, leader: riderName(context, other.displayName), hm: hm);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          GlyphIcon(Glyph.podium, size: 14, color: standing.leading ? c.accent : c.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('live-duel-line'),
              style: AppText.caption(standing.leading ? c.accent : c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
