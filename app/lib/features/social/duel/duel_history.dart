import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import 'duel_models.dart';
import 'duel_providers.dart';
import 'duel_result_card.dart';
import 'duel_strings.dart';

/// Past duels under the Tagesduell card: 'Gestern · Platz 2 von 3 · 1.849 hm'
/// per row, newest first, at most [max]; a tap opens the result sheet.
/// Renders nothing while there is no past duel (signed out, offline, none).
class DuelHistoryList extends ConsumerWidget {
  const DuelHistoryList({super.key, this.ownUserId, this.now, this.max = 5});

  final String? ownUserId;

  /// Clock for the day labels; null = the wall clock.
  final DateTime? now;
  final int max;

  /// Duels of days before [now]'s date, newest first.
  static List<DuelSummary> past(List<DuelSummary> duels, DateTime now, {int max = 5}) {
    final today = DateTime(now.year, now.month, now.day);
    final rows = duels.where((d) => d.day.isBefore(today)).toList()..sort((a, b) => b.day.compareTo(a.day));
    return rows.take(max).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final ds = DuelStrings.of(context);
    final l = AppLocale.of(context).code;
    final clock = now ?? DateTime.now();
    final duels = ref.watch(myDuelsProvider).asData?.value ?? const <DuelSummary>[];
    final rows = past(duels, clock, max: max);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ds.history.toUpperCase(), style: AppText.label(c.textTertiary)),
          const SizedBox(height: 4),
          for (final d in rows)
            Pressable(
              onTap: () => DuelResultSheet.show(context, d, ownUserId: ownUserId),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ds.historyLine(
                          day: ds.dayLabel(d.day, clock),
                          place: d.placeOf(ownUserId),
                          of: d.participants,
                          hm: Fmt.metres(d.rowOf(ownUserId)?.dropM ?? 0, locale: l),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyText(c.textSecondary, size: 15),
                      ),
                    ),
                    const RowChevron(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The result of one duel as a sheet — the same card the Tagesbilanz shows.
class DuelResultSheet {
  const DuelResultSheet._();

  static Future<void> show(BuildContext context, DuelSummary duel, {String? ownUserId}) => AppSheet.show<void>(
        context,
        title: duel.group.name,
        builder: (_) => Padding(
          padding: const EdgeInsets.only(bottom: Tokens.pad),
          child: DuelResultCard(duel: duel, ownUserId: ownUserId),
        ),
      );
}
