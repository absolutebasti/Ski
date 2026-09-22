import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/db/providers.dart';
import '../../data/weather/wmo.dart';
import '../map/map.dart';
import '../profile/profile.dart';
import 'day_actions.dart';
import 'days_strings.dart';
import 'run_list.dart';
import 'stats_grid.dart';

/// Tag detail, pushed from Tage (docs/PLAN.md §3 row "Tag"). Fixed order:
/// header · map · altitude profile · time bar · stats grid · runs · actions.
/// Scrubbing the profile moves the marker on the map.
class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({super.key, required this.dayId, this.tilesEnabled = true, this.mapHeight = 240});

  final String dayId;

  /// `false` in widget tests: the map draws the track without any tile layer.
  final bool tilesEnabled;
  final double mapHeight;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  int? _scrubTs;

  void _onScrub(int? ts) {
    if (ts == _scrubTs) return;
    setState(() => _scrubTs = ts);
  }

  Future<void> _share() async {
    final action = await showShareMenu(context);
    if (action == null || !mounted) return;
    switch (action) {
      case DayShareAction.card:
        await shareDayCardById(context, ref, widget.dayId);
      case DayShareAction.gpx:
        await shareDayGpxById(ref, widget.dayId);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDeleteDay(context);
    if (!ok || !mounted) return;
    await deleteDayById(ref, widget.dayId);
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = DaysStrings.of(context);
    final detail = ref.watch(dayDetailProvider(widget.dayId));

    return Scaffold(
      appBar: AppBar(title: Text(s.dayTitle)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.pad),
            child: Text(s.loadFailed, style: AppText.bodyText(c.textSecondary), textAlign: TextAlign.center),
          ),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(DayDetail d) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final st = d.day.stats;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.pad, 4, Tokens.pad, 40),
      children: [
        _Header(day: d.day),
        const SizedBox(height: 20),
        if (d.points.isEmpty)
          Text(s.noTrack, style: AppText.bodyText(c.textSecondary, size: 15))
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radius),
            child: SizedBox(
              height: widget.mapHeight,
              child: TrackMap(
                points: d.points,
                segments: d.segments,
                scrubTs: _scrubTs,
                tilesEnabled: widget.tilesEnabled,
              ),
            ),
          ),
        const SizedBox(height: 16),
        AltitudeProfile(points: d.points, segments: d.segments, onScrub: _onScrub),
        const SizedBox(height: 24),
        StackedTimeBar(
          skiMs: st.skiMs,
          liftMs: st.liftMs,
          pauseMs: st.pauseMs,
          signalLossMs: st.signalLossMs,
          otherMs: st.otherMs,
          labels: s.timeBarLabels,
        ),
        const SizedBox(height: 8),
        Text(s.total(Fmt.durationCompact(st.elapsedMs, locale: l.code)), style: AppText.label(c.textSecondary, size: 12)),
        const SizedBox(height: 24),
        StatsGrid(detail: d),
        const SizedBox(height: 24),
        RunList(segments: d.segments),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: PrimaryButton(label: s.share, icon: Icons.ios_share_rounded, onPressed: _share)),
            const SizedBox(width: 12),
            SecondaryButton(label: s.delete, icon: Icons.delete_outline_rounded, onPressed: _delete),
          ],
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.day});
  final DayRecord day;

  /// The snapshot stored at End, or null when the day has none / is unreadable.
  static WeatherSnapshot? weatherOf(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return null;
      return WeatherSnapshot.fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final st = day.stats;
    final w = weatherOf(day.weatherJson);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Fmt.dateLong(day.startedAt, locale: l.code), style: AppText.headline(c.textPrimary, size: 26)),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: Text(
                day.resortName ?? s.freeTerrain,
                style: AppText.bodyText(c.textSecondary, size: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (w != null) ...[
              const SizedBox(width: 10),
              Icon(wmoIcon(wmoBucket(w.wmoCode)), size: 16, color: c.textSecondary),
              if (w.tempSummitC != null || w.tempBaseC != null) ...[
                const SizedBox(width: 5),
                Text(Fmt.temp((w.tempSummitC ?? w.tempBaseC)!), style: AppText.bodyText(c.textSecondary, size: 16)),
              ],
            ],
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: HeroNumber(value: '${st.runCount}', label: s.runs, size: 30)),
            Expanded(child: HeroNumber(value: Fmt.metres(st.dropM, locale: l.code), unit: s.unitHm, label: s.vertical, size: 30)),
            Expanded(child: HeroNumber(value: Fmt.kmh(st.maxSpeedMs, locale: l.code), unit: s.unitKmh, label: s.topSpeed, size: 30)),
          ],
        ),
      ],
    );
  }
}
