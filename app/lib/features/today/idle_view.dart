import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/db/providers.dart';
import '../../data/resorts/resort_repository.dart';
import '../../platform/permission_service.dart';
import '../recording/recording_controller.dart';
import '../settings/settings_providers.dart';
import '../weather/weather_line.dart';
import 'today_strings.dart';

/// Heute before a day is running: where you are, what you did last, and the
/// one 72 pt button in the thumb zone (docs/PLAN.md §3 row "Heute — idle").
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

  /// The card to show: a failed Start wins, otherwise the resting permission state.
  RecordingErrorKind? _cardFor(LocationPermissionState? status, bool? precise) {
    if (error != null) return error;
    if (status == LocationPermissionState.denied || status == LocationPermissionState.deniedForever) {
      return RecordingErrorKind.locationDenied;
    }
    if (precise == false) return RecordingErrorKind.reducedAccuracy;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = TodayStrings.of(context);
    final days = ref.watch(daysListProvider).asData?.value ?? const <DaySummary>[];
    final totals = ref.watch(seasonTotalsProvider).asData?.value ?? const <SeasonTotals>[];
    final resortId = ref.watch(settingsProvider).lastResortId;
    final resort = resortId == null ? null : ref.watch(resortRepositoryProvider).asData?.value.byId(resortId);
    final status = ref.watch(locationStatusProvider).asData?.value;
    final precise = ref.watch(preciseLocationProvider).asData?.value;
    final card = _cardFor(status, precise);
    final startBlocked = card == RecordingErrorKind.reducedAccuracy;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 4, Tokens.pad, 8),
            children: [
              if (resort != null) ...[
                const SizedBox(height: 4),
                WeatherLine(resort: resort),
                const SizedBox(height: 20),
              ],
              if (days.isEmpty) ...[
                const SizedBox(height: 24),
                EmptyState(line: s.emptyLine),
              ] else ...[
                _LastDayCard(day: days.first),
                const SizedBox(height: 16),
                _SeasonRow(totals: totals.isEmpty ? null : totals.first),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, Tokens.pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recovery != null) ...[recovery!, const SizedBox(height: 12)],
              if (card != null) ...[
                _StartBlockedCard(
                  kind: card,
                  onOpenSettings: onOpenSettings,
                  onRequestPrecise: onRequestPrecise,
                ),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: s.start,
                height: Tokens.startButton,
                icon: Icons.play_arrow_rounded,
                onPressed: busy || startBlocked ? null : onStart,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LastDayCard extends StatelessWidget {
  const _LastDayCard({required this.day});
  final DaySummary day;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final st = day.stats;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.lastDay.toUpperCase(), style: AppText.label(c.textSecondary)),
          const SizedBox(height: 8),
          Text(
            '${Fmt.dateShort(day.startedAt, locale: l.code)}${day.resortName == null ? '' : ' · ${day.resortName}'}',
            style: AppText.title(c.textPrimary, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            s.dayLine(
              runs: st.runCount,
              dropM: Fmt.metres(st.dropM, locale: l.code),
              kmh: Fmt.kmh(st.maxSpeedMs, locale: l.code),
            ),
            style: AppText.bodyText(c.textSecondary, size: 15),
          ),
        ],
      ),
    );
  }
}

class _SeasonRow extends StatelessWidget {
  const _SeasonRow({required this.totals});
  final SeasonTotals? totals;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final t = totals ?? SeasonTotals(seasonKey: seasonKey(DateTime.now()));
    return Row(
      children: [
        Text(s.season.toUpperCase(), style: AppText.label(c.textSecondary)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            s.seasonLine(
              season: t.seasonKey,
              days: t.dayCount,
              runs: t.runCount,
              dropM: Fmt.metres(t.dropM, locale: l.code),
            ),
            style: AppText.bodyText(c.textSecondary, size: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_off_rounded, size: 18, color: c.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppText.bodyText(c.textPrimary, size: 16, weight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: AppText.bodyText(c.textSecondary, size: 15)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: SecondaryButton(label: action, onPressed: onTap))]),
        ],
      ),
    );
  }
}
