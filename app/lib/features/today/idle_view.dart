import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/db/providers.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/weather/weather_provider.dart';
import '../../data/weather/wmo.dart';
import '../../platform/permission_service.dart';
import '../days/day_card.dart';
import '../recording/recording_controller.dart';
import '../settings/settings_providers.dart';
import '../weather/weather_line.dart';
import 'season_card.dart';
import 'today_strings.dart';

/// Heute before a day is running (docs/DESIGN.md §5 "Heute — idle"):
/// conditions strip · SAISON hero · Letzter Tag row · PB strip · dock with Start.
class IdleView extends ConsumerWidget {
  const IdleView({
    super.key,
    required this.onStart,
    required this.onOpenSettings,
    required this.onRequestPrecise,
    this.error,
    this.busy = false,
    this.recovery,
  });

  final VoidCallback onStart;
  final VoidCallback onOpenSettings;
  final VoidCallback onRequestPrecise;
  final RecordingErrorKind? error;
  final bool busy;
  final Widget? recovery;

  RecordingErrorKind? _cardFor(LocationPermissionState? status, bool? precise) {
    if (error != null) return error;
    if (status == LocationPermissionState.denied || status == LocationPermissionState.deniedForever) return RecordingErrorKind.locationDenied;
    if (precise == false) return RecordingErrorKind.reducedAccuracy;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final days = ref.watch(daysListProvider).asData?.value ?? const <DaySummary>[];
    final totals = ref.watch(seasonTotalsProvider).asData?.value ?? const <SeasonTotals>[];
    final bests = ref.watch(personalBestsProvider).asData?.value;
    final resortId = ref.watch(settingsProvider).lastResortId;
    final resort = resortId == null ? null : ref.watch(resortRepositoryProvider).asData?.value.byId(resortId);
    final status = ref.watch(locationStatusProvider).asData?.value;
    final precise = ref.watch(preciseLocationProvider).asData?.value;
    final card = _cardFor(status, precise);
    final startBlocked = card == RecordingErrorKind.reducedAccuracy;
    final currentKey = seasonKey(DateTime.now());
    final season = totals.where((t) => t.seasonKey == currentKey).firstOrNull ?? (totals.isNotEmpty ? totals.first : null);
    final previous = season == null ? null : totals.where((t) => t.seasonKey.compareTo(season.seasonKey) < 0).firstOrNull;
    final seasonDays = season == null ? const <DaySummary>[] : days.where((d) => seasonKeyFromMs(d.startedAt) == season.seasonKey).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, 24),
            children: [
              if (resort != null) ...[
                _ConditionsStrip(resort: resort),
                const SizedBox(height: Tokens.cardGap),
              ],
              if (days.isEmpty) ...[
                const SizedBox(height: 8),
                EmptyState(headline: s.emptyHeadline, line: s.emptyLine),
              ] else ...[
                if (season != null) SeasonCard(totals: season, days: seasonDays, previous: previous),
                SectionLabel(s.lastDay, padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10)),
                DayCard(day: days.first, onTap: () => AppNav.openDay(context, days.first.id)),
                if (bests != null && (bests.topSpeedMs != null || bests.biggestDayDropM != null || bests.longestRunDropM != null)) ...[
                  SectionLabel(s.records, padding: const EdgeInsets.fromLTRB(0, 16, 0, 10)),
                  _PbStrip(bests: bests),
                ],
              ],
            ],
          ),
        ),
        BottomDock(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recovery != null) ...[recovery!, const SizedBox(height: 12)],
              if (card != null) ...[
                _StartBlockedCard(kind: card, onOpenSettings: onOpenSettings, onRequestPrecise: onRequestPrecise),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: s.start,
                height: Tokens.startButton,
                glyph: Glyph.play,
                onPressed: busy || startBlocked ? null : onStart,
              ),
              const SizedBox(height: 8),
              Text(s.startHint, style: AppText.caption(c.textTertiary, size: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    ).also((_) => l);
  }
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}

/// Bedingungen: weather glyph, WeatherLine, right-aligned caption.
class _ConditionsStrip extends ConsumerWidget {
  const _ConditionsStrip({required this.resort});
  final Resort resort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final w = ref.watch(weatherProvider(resort)).asData?.value;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(wmoIcon(wmoBucket(w?.wmoCode)), size: 22, color: c.ice),
          const SizedBox(width: 12),
          Expanded(
            child: Text(WeatherLine.format(resort, w, de: l.isGerman), style: AppText.bodyText(c.textPrimary, size: 16, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _PbStrip extends StatelessWidget {
  const _PbStrip({required this.bests});
  final PersonalBests bests;

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final tiles = <Widget>[
      if (bests.topSpeedMs != null) PbTile(label: s.topSpeed, value: Fmt.kmh(bests.topSpeedMs!, locale: l.code), unit: s.unitKmh),
      if (bests.biggestDayDropM != null) PbTile(label: s.biggestDay, value: Fmt.metres(bests.biggestDayDropM!, locale: l.code), unit: s.unitHm),
      if (bests.longestRunDropM != null) PbTile(label: s.longestRun, value: Fmt.metres(bests.longestRunDropM!, locale: l.code), unit: s.unitHm),
    ];
    return Row(
      children: [
        for (final (i, t) in tiles.indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: t)],
      ],
    );
  }
}

/// 'Standort ist aus' / 'Ortungsdienste sind aus' / 'Genauer Standort fehlt'.
class _StartBlockedCard extends StatelessWidget {
  const _StartBlockedCard({required this.kind, required this.onOpenSettings, required this.onRequestPrecise});
  final RecordingErrorKind kind;
  final VoidCallback onOpenSettings;
  final VoidCallback onRequestPrecise;

  @override
  Widget build(BuildContext context) {
    if (kind == RecordingErrorKind.alreadyRecording) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final s = TodayStrings.of(context);
    final (title, body, action, onTap) = switch (kind) {
      RecordingErrorKind.locationDenied => (s.deniedTitle, s.deniedBody, s.openSettings, onOpenSettings),
      RecordingErrorKind.locationServiceOff => (s.serviceOffTitle, s.serviceOffBody, s.openSettings, onOpenSettings),
      RecordingErrorKind.reducedAccuracy => (s.preciseTitle, s.preciseBody, s.preciseAction, onRequestPrecise),
      RecordingErrorKind.alreadyRecording => (s.recording, '', s.openSettings, onOpenSettings),
    };
    return AppCard(
      tone: CardTone.danger,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_off_rounded, size: 20, color: c.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppText.bodyStrong(c.textPrimary))),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: AppText.bodyText(c.textSecondary, size: 15)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: SecondaryButton(label: action, onPressed: onTap, height: 48))]),
        ],
      ),
    );
  }
}
