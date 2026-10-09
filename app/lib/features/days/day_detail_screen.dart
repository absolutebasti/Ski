import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/db/providers.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/weather/wmo.dart';
import '../map/map.dart';
import '../profile/profile.dart';
import '../summary/time_legend.dart';
import 'day_actions.dart';
import 'day_skeleton.dart';
import 'days_strings.dart';
import 'resort_picker.dart';
import 'run_list.dart';
import 'stats_grid.dart';
import 'track_restore.dart';
import '../share/share_strings.dart';

/// Tag detail (docs/DESIGN.md §5 "Tag — Detail"). The map is the hero: full
/// bleed from the very top edge, collapsing into a 52 pt bar on scroll. Then
/// the 3-up hero numbers, the altitude profile (scrub moves the map marker),
/// the time bar, the 2×4 stat grid, the run table and the dock.
class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({super.key, required this.dayId, this.tilesEnabled = true, this.mapHeight = heroHeight});

  final String dayId;

  /// `false` in widget tests: the map draws the track without any tile layer.
  final bool tilesEnabled;

  /// Expanded height of the map hero.
  final double mapHeight;

  static const double heroHeight = 320;
  static const double collapsedHeight = 52;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

/// What the hero surface offers for a day without local points.
enum TrackRestoreState { none, available, loading }

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  int? _scrubTs;
  bool _restoring = false;

  void _onScrub(int? ts) {
    if (ts == _scrubTs) return;
    setState(() => _scrubTs = ts);
  }

  void _back() {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  Future<void> _share() async {
    final action = await showShareMenu(context);
    if (action == null || !mounted) return;
    switch (action) {
      case DayShareAction.card:
        await shareDayCardById(context, ref, widget.dayId);
      case DayShareAction.gpx:
        await shareDayGpxById(ref, widget.dayId, strings: ShareStrings.of(context));
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDeleteDay(context);
    if (!ok || !mounted) return;
    await deleteDayById(ref, widget.dayId);
    if (!mounted) return;
    _back();
  }

  /// 'Skigebiet ändern': picker nearest-first to the day's first point, then
  /// DaysRepository.updateResort (re-queues the day for sync).
  Future<void> _changeResort(DayDetail d) async {
    List<Resort> resorts;
    try {
      resorts = (await ref.read(resortRepositoryProvider.future)).all;
    } on Object {
      resorts = const [];
    }
    if (!mounted) return;
    final first = TrackGeometry.first(d.points);
    final pick = await ResortPickerSheet.show(context, resorts: resorts, lat: first?.latitude, lon: first?.longitude, currentId: d.day.resortId);
    if (pick == null || !mounted) return;
    if (pick.resort?.id == d.day.resortId) return;
    await ref.read(daysRepositoryProvider).updateResort(widget.dayId, pick.resort?.id, pick.resort?.name);
    ref.invalidate(dayDetailProvider(widget.dayId));
    if (mounted) showToast(context, DaysStrings.of(context).resortChanged);
  }

  /// 'Spur laden': the bridge downloads the bundle; the detail reloads after.
  Future<void> _restoreTrack() async {
    final bridge = ref.read(dayTrackRestoreProvider);
    if (bridge == null || _restoring) return;
    setState(() => _restoring = true);
    try {
      await bridge.restore(widget.dayId);
      ref.invalidate(dayDetailProvider(widget.dayId));
    } on Object {
      if (mounted) showToast(context, DaysStrings.of(context).trackLoadFailed);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = DaysStrings.of(context);
    final detail = ref.watch(dayDetailProvider(widget.dayId));

    return Scaffold(
      backgroundColor: c.bg,
      body: PageBackground(
        child: detail.when(
          loading: () => _loading(),
          error: (e, _) => _fallback(
            Text(s.loadFailed, style: AppText.bodyText(c.textSecondary), textAlign: TextAlign.center),
          ),
          data: _body,
        ),
      ),
    );
  }

  /// Loading: the skeleton of the page, back circle floating top-left.
  Widget _loading() {
    final s = DaysStrings.of(context);
    return Stack(
      children: [
        Positioned.fill(child: DayDetailSkeleton(mapHeight: widget.mapHeight)),
        Positioned(left: Tokens.pad, top: MediaQuery.paddingOf(context).top + 6, child: HeaderButton(glyph: Glyph.back, tooltip: s.back, onTap: _back)),
      ],
    );
  }

  /// Error: no map, but the back circle still floats top-left.
  Widget _fallback(Widget child) {
    final s = DaysStrings.of(context);
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(child: Center(child: Padding(padding: const EdgeInsets.all(Tokens.pad), child: child))),
          Positioned(left: Tokens.pad, top: 8, child: HeaderButton(glyph: Glyph.back, tooltip: s.back, onTap: _back)),
        ],
      ),
    );
  }

  Widget _body(DayDetail d) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final st = d.day.stats;
    final hasRemote = d.points.isEmpty && (ref.watch(dayHasRemoteTrackProvider(widget.dayId)).asData?.value ?? false);
    final restore = _restoring
        ? TrackRestoreState.loading
        : hasRemote
            ? TrackRestoreState.available
            : TrackRestoreState.none;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: MapHeroHeader(
                  detail: d,
                  tilesEnabled: widget.tilesEnabled,
                  scrubTs: _scrubTs,
                  expandedHeight: widget.mapHeight,
                  topInset: MediaQuery.paddingOf(context).top,
                  onBack: _back,
                  onShare: _share,
                  onChangeResort: () => _changeResort(d),
                  restore: restore,
                  onRestore: _restoreTrack,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Tokens.pad, 24, Tokens.pad, 32),
                sliver: SliverList.list(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 12 pt gutters: a scaled-down '1.849 m' must never touch the next column.
                        Expanded(child: _Hero(value: '${st.runCount}', label: s.runs)),
                        const SizedBox(width: 12),
                        Expanded(child: _Hero(value: Fmt.metres(st.dropM, locale: l.code), unit: s.unitHm, label: s.vertical)),
                        const SizedBox(width: 12),
                        Expanded(child: _Hero(value: Fmt.kmh(st.maxSpeedMs, locale: l.code), unit: s.unitKmh, label: s.topSpeed)),
                      ],
                    ),
                    const SizedBox(height: Tokens.sectionGap),
                    AppCard(
                      header: s.altitudeProfile,
                      padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                      child: AltitudeProfile(points: d.points, segments: d.segments, onScrub: _onScrub, height: 132),
                    ),
                    const SizedBox(height: Tokens.cardGap),
                    AppCard(
                      header: s.timeSection,
                      trailing: Text(Fmt.durationCompact(st.elapsedMs, locale: l.code), style: AppText.numXs(c.textPrimary)),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _TimeBar(stats: st, labels: s.timeBarLabels),
                      ),
                    ),
                    const SizedBox(height: Tokens.sectionGap),
                    StatsGrid(detail: d),
                    SectionLabel(s.runs, padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10)),
                    RunList(segments: d.segments),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Text-only: the hero already carries the share glyph, and a destructive
        // row takes the danger label without an icon (docs/DESIGN.md §5).
        BottomDock(
          child: Row(
            children: [
              Expanded(child: PrimaryButton(label: s.share, onPressed: _share)),
              const SizedBox(width: 12),
              SecondaryButton(label: s.delete, danger: true, onPressed: _delete),
            ],
          ),
        ),
      ],
    );
  }
}

/// 44 pt numeral with the overline above; scaled down on narrow phones so
/// '1.804' never wraps.
class _Hero extends StatelessWidget {
  const _Hero({required this.value, required this.label, this.unit});
  final String value;
  final String label;
  final String? unit;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: HeroNumber(value: value, unit: unit, label: label, size: 40),
      );
}

/// The collapsing map hero. Exposed for tests.
class MapHeroHeader extends SliverPersistentHeaderDelegate {
  const MapHeroHeader({
    required this.detail,
    required this.tilesEnabled,
    required this.scrubTs,
    required this.expandedHeight,
    required this.topInset,
    required this.onBack,
    required this.onShare,
    this.onChangeResort,
    this.restore = TrackRestoreState.none,
    this.onRestore,
  });

  final DayDetail detail;
  final bool tilesEnabled;
  final int? scrubTs;
  final double expandedHeight;
  final double topInset;
  final VoidCallback onBack;
  final VoidCallback onShare;
  /// Tapping the resort line in the plate opens the picker; null hides the affordance.
  final VoidCallback? onChangeResort;
  /// 'Spur laden' for a day whose points live only in the cloud.
  final TrackRestoreState restore;
  final VoidCallback? onRestore;

  /// The tag the Tage row's path thumbnail flies from (see day_card.dart). The
  /// satellite card carries no Hero, so from there the detail simply opens.
  String get heroTag => 'route-${detail.day.id}';

  @override
  double get minExtent => DayDetailScreen.collapsedHeight + topInset;

  @override
  double get maxExtent => math.max(expandedHeight, minExtent + 1);

  @override
  bool shouldRebuild(MapHeroHeader old) =>
      !identical(old.detail, detail) ||
      old.scrubTs != scrubTs ||
      old.tilesEnabled != tilesEnabled ||
      old.expandedHeight != expandedHeight ||
      old.topInset != topInset ||
      old.restore != restore ||
      old.onChangeResort != onChangeResort;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final date = Fmt.dateLong(detail.day.startedAt, locale: l.code);
    // Cross-fade: the plate is out at half collapse, the bar title starts just
    // before that and is fully in at three quarters.
    final plate = (1 - t * 2).clamp(0.0, 1.0);
    final barTitle = ((t - 0.35) / 0.4).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // The map keeps its full 320 pt layout and is clipped as the bar shrinks.
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: maxExtent,
            maxHeight: maxExtent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Hero(
                    tag: heroTag,
                    flightShuttleBuilder: _shuttle,
                    child: _Route(detail: detail, tilesEnabled: tilesEnabled, scrubTs: scrubTs, restore: restore, onRestore: onRestore),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [c.ink.withValues(alpha: 0.55), Colors.transparent, c.ink.withValues(alpha: 0.80)],
                          stops: const [0, 0.34, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                if (plate > 0)
                  Positioned(
                    left: Tokens.pad,
                    right: Tokens.pad,
                    bottom: 18,
                    child: Opacity(opacity: plate, child: _DatePlate(day: detail.day, date: date, onChangeResort: onChangeResort)),
                  ),
              ],
            ),
          ),
        ),
        // Collapsed bar: solid graphite + hairline, fading in over the map.
        IgnorePointer(
          child: Opacity(
            opacity: t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(bottom: BorderSide(color: c.hairline, width: c.hairlineWidth)),
              ),
            ),
          ),
        ),
        if (barTitle > 0)
          Positioned(
            top: topInset,
            left: 72,
            right: 72,
            height: DayDetailScreen.collapsedHeight,
            child: Opacity(
              opacity: barTitle,
              child: Center(child: Text(date, style: AppText.displayS(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ),
          ),
        Positioned(left: Tokens.pad, top: topInset + 6, child: HeaderButton(glyph: Glyph.back, tooltip: s.back, onTap: onBack)),
        Positioned(right: Tokens.pad, top: topInset + 6, child: HeaderButton(glyph: Glyph.share, tooltip: s.share, onTap: onShare)),
      ],
    );
  }

  /// The flight from a Tage row draws the route itself — cheap, and it looks
  /// like the thumbnail the user tapped.
  Widget _shuttle(BuildContext flight, Animation<double> animation, HeroFlightDirection direction, BuildContext from, BuildContext to) {
    final c = AppColors.of(flight);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = direction == HeroFlightDirection.push ? animation.value : 1 - animation.value;
        return ClipPath(
          clipper: ShapeBorderClipper(shape: Squircle.plain(lerpDouble(Tokens.r10, 0, v)!)),
          child: CustomPaint(
            painter: TrackThumbnailPainter(
              points: detail.points,
              segments: detail.segments,
              background: c.routeGround,
              runColor: c.run,
              liftColor: c.liftGrey,
              padding: lerpDouble(10, 44, v)!,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// The hero surface itself: the live map, or the contour fallback with a
/// typeset line — never a pictogram.
class _Route extends StatelessWidget {
  const _Route({required this.detail, required this.tilesEnabled, required this.scrubTs, this.restore = TrackRestoreState.none, this.onRestore});
  final DayDetail detail;
  final bool tilesEnabled;
  final int? scrubTs;
  final TrackRestoreState restore;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = DaysStrings.of(context);
    if (detail.points.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: TrackThumbnailPainter(points: const [], background: c.routeGround, liftColor: c.liftGrey)),
          Center(
            child: switch (restore) {
              TrackRestoreState.none => Text(s.withoutTrack.overline, style: AppText.label(c.textTertiary, size: 12)),
              // Typeset only — nothing spins on a route surface.
              TrackRestoreState.loading => Text(s.loadingTrack.overline, style: AppText.label(c.accent, size: 12)),
              TrackRestoreState.available => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.withoutTrack.overline, style: AppText.label(c.textTertiary, size: 12)),
                    const SizedBox(height: 12),
                    SecondaryButton(label: s.loadTrack, icon: Icons.cloud_download_rounded, height: Tokens.buttonSm, onPressed: onRestore),
                  ],
                ),
            },
          ),
        ],
      );
    }
    return TrackMap(
      points: detail.points,
      segments: detail.segments,
      scrubTs: scrubTs,
      tilesEnabled: tilesEnabled,
      // The hero sits inside a scroll view: panning it would fight the list.
      interactive: false,
    );
  }
}

/// Bottom-left plate over the map: date 22 + resort / weather caption.
class _DatePlate extends StatelessWidget {
  const _DatePlate({required this.day, required this.date, this.onChangeResort});
  final DayRecord day;
  final String date;
  final VoidCallback? onChangeResort;

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
    final s = DaysStrings.of(context);
    final w = weatherOf(day.weatherJson);
    final temp = w == null ? null : (w.tempSummitC ?? w.tempBaseC);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 16, 12),
        decoration: ShapeDecoration(
          color: Color.alphaBlend(c.glassFill, c.ink.withValues(alpha: 0.62)),
          shape: Squircle.border(Tokens.r14, side: c.glassStroke, width: c.hairlineWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(date, style: AppText.headline(c.textPrimary, size: 22), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: _ResortLine(name: day.resortName ?? s.freeTerrain, onTap: onChangeResort)),
                if (w != null) ...[
                  const SizedBox(width: 10),
                  Icon(wmoIcon(wmoBucket(w.wmoCode)), size: 14, color: c.textSecondary),
                  if (temp != null) ...[
                    const SizedBox(width: 5),
                    Text(Fmt.temp(temp), style: AppText.numXs(c.textPrimary).copyWith(fontSize: 13)),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Resort caption in the plate; with [onTap] it is the 'Skigebiet ändern'
/// affordance (caption + 14 pt chevron, 44 pt tall hit area).
class _ResortLine extends StatelessWidget {
  const _ResortLine({required this.name, this.onTap});
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = DaysStrings.of(context);
    final text = Text(name, style: AppText.caption(c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis);
    if (onTap == null) return text;
    return Semantics(
      button: true,
      label: s.changeResort,
      child: Pressable(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: text),
            const SizedBox(width: 4),
            const RowChevron(inline: true),
          ],
        ),
      ),
    );
  }
}

/// ZEIT bar of the detail: whole-minute segments whose sum equals the header
/// value (the pause takes the remainder — see [timeLegendSegments]).
class _TimeBar extends StatelessWidget {
  const _TimeBar({required this.stats, required this.labels});
  final DayStats stats;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final seg = timeLegendSegments(stats);
    return StackedTimeBar(
      skiMs: seg.skiMs,
      liftMs: seg.liftMs,
      pauseMs: seg.pauseMs,
      signalLossMs: seg.signalLossMs,
      labels: labels,
    );
  }
}
