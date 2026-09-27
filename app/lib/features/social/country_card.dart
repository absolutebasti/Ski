import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import 'leaderboard_providers.dart';
import 'social_api.dart';
import 'social_models.dart';
import 'social_strings.dart';

/// 'Länder' — the Team-Wertung (RPC `country_board`, migration 0004):
/// flag · country · riders, points as the numeral, the own team ringed in
/// champagne. Reads [countryBoardProvider] for [seasonKey].
///
/// Offline or failed → the card shrinks to its caption line; the Rangliste
/// above already explains the connection state.
class CountryBoardCard extends ConsumerWidget {
  const CountryBoardCard({super.key, required this.seasonKey, required this.period, this.ownCountryCode, this.maxRows = 8});

  /// Season/month/week key as sent to the RPC.
  final String seasonKey;
  final LeaderboardPeriod period;

  /// `Settings.countryCode`; null = nothing highlighted.
  final String? ownCountryCode;
  final int maxRows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final board = ref.watch(countryBoardProvider(seasonKey));
    final own = ownCountryCode?.toUpperCase();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Tokens.cardPad, Tokens.cardPad, Tokens.cardPad, 8),
      header: s.countries,
      trailing: Text(s.countriesCaption(period), style: AppText.caption(c.textTertiary, size: 12)),
      child: board.when(
        loading: () => const _Skeleton(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            e is SocialError ? s.error(e.kind) : s.error(SocialErrorKind.failed),
            style: AppText.caption(c.textSecondary),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(s.countriesEmpty, style: AppText.caption(c.textSecondary)));
          }
          final shown = entries.take(maxRows).toList();
          // Keep the own team visible even when it sits below the cut.
          if (own != null && !shown.any((e) => e.countryCode == own)) {
            final mine = entries.where((e) => e.countryCode == own).firstOrNull;
            if (mine != null) shown.add(mine);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, e) in shown.indexed) ...[
                if (i > 0) const Hairline(),
                CountryRow(rank: entries.indexOf(e) + 1, entry: e, own: e.countryCode == own),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One team: rank · flag (ringed when [own]) · country + riders · points.
class CountryRow extends StatelessWidget {
  const CountryRow({super.key, required this.rank, required this.entry, this.own = false});

  final int rank;
  final CountryEntry entry;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SocialStrings.of(context);
    final (value, unit) = s.value(SocialMetric.points, entry.points);
    final name = s.countryName(entry.countryCode);
    return Semantics(
      label: '$rank · $name · ${s.riders(entry.riders)} · ${s.valueLine(SocialMetric.points, entry.points)}',
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: own
            ? ShapeDecoration(color: c.accentWash, shape: Squircle.plain(Tokens.r10))
            : null,
        padding: EdgeInsets.symmetric(horizontal: own ? 8 : 0),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text('$rank', style: AppText.numXs(c.textTertiary))),
            CountryFlag(countryCode: entry.countryCode, ring: own),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyText(c.textPrimary, size: 15, weight: own ? FontWeight.w700 : FontWeight.w500)),
                  Text(s.riders(entry.riders), style: AppText.caption(own ? c.accent : c.textTertiary, size: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppText.numS(own ? c.accent : c.textPrimary)),
                if (unit != null) ...[const SizedBox(width: 4), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Flag emoji in a 36 pt circle; [ring] = 1.5 pt champagne ring (own team).
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.countryCode, this.ring = false, this.size = 36});

  final String countryCode;
  final bool ring;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final flag = flagEmoji(countryCode);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: ring ? c.accent : c.hairline, width: ring ? 1.5 : c.hairlineWidth),
      ),
      child: Text(
        flag.isEmpty ? countryCode : flag,
        style: flag.isEmpty ? AppText.label(c.textSecondary) : TextStyle(fontSize: size * 0.5, height: 1),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: 0.06,
              child: Container(height: 48, decoration: ShapeDecoration(color: c.textPrimary, shape: Squircle.plain(Tokens.r10))),
            ),
          ),
      ],
    );
  }
}
