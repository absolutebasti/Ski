import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/surfaces.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/core.dart';
import 'profile_series.dart';
import 'profile_strings.dart';

/// Time-based altitude profile of one ski day (docs/DESIGN.md §4 "Charts").
///
/// x = elapsed time since the first accepted point, y = fused altitude.
/// Champagne 2 pt stroke over an accent area that fades to nothing, lift rides
/// shaded liftGrey, signal-loss gaps hatched danger. Dragging over the chart
/// draws a 1 px ice cursor with a floating glass readout ("11:42 · 1.980 m")
/// and reports the touched point's `ts` via [onScrub] (null when the finger
/// lifts).
class AltitudeProfile extends StatefulWidget {
  const AltitudeProfile({super.key, required this.points, required this.segments, this.onScrub, this.height = 200});

  final List<TrackPoint> points;
  final List<Segment> segments;
  final ValueChanged<int?>? onScrub;
  final double height;

  /// Space fl_chart reserves for the altitude labels on the left.
  static const double leftAxis = 48;

  /// Space fl_chart reserves for the time labels at the bottom.
  static const double bottomAxis = 22;

  @override
  State<AltitudeProfile> createState() => _AltitudeProfileState();
}

class _AltitudeProfileState extends State<AltitudeProfile> {
  late ProfileSeries _series = ProfileSeries.build(widget.points, widget.segments);
  ProfileSample? _scrub;

  @override
  void didUpdateWidget(AltitudeProfile old) {
    super.didUpdateWidget(old);
    if (!identical(old.points, widget.points) || !identical(old.segments, widget.segments)) {
      _series = ProfileSeries.build(widget.points, widget.segments);
      _scrub = null;
    }
  }

  void _setScrub(ProfileSample? s) {
    if (s?.ts == _scrub?.ts) return;
    setState(() => _scrub = s);
    widget.onScrub?.call(s?.ts);
  }

  void _onTouch(FlTouchEvent event, LineTouchResponse? response) {
    final ended = event is FlPanEndEvent ||
        event is FlPanCancelEvent ||
        event is FlTapUpEvent ||
        event is FlLongPressEnd ||
        event is FlPointerExitEvent;
    if (ended) {
      _setScrub(null);
      return;
    }
    final spot = response?.lineBarSpots?.firstOrNull;
    if (spot == null) return;
    _setScrub(_series.nearest(spot.x));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = ProfileStrings.of(context);
    if (_series.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text(s.noData, style: AppText.bodyText(c.textTertiary, size: 15))),
      );
    }
    final axis = _series.altitudeAxis;
    final scrub = _scrub;
    final maxX = _series.durationS <= 0 ? 1.0 : _series.durationS;
    final spots = [for (final p in _series.samples) FlSpot(p.elapsedS, p.altM)];

    final data = LineChartData(
      minX: 0,
      maxX: maxX,
      minY: axis.min,
      maxY: axis.max,
      clipData: const FlClipData.all(),
      backgroundColor: Colors.transparent,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: axis.interval,
        getDrawingHorizontalLine: (_) => FlLine(color: c.hairline, strokeWidth: c.hairlineWidth),
      ),
      rangeAnnotations: RangeAnnotations(
        verticalRangeAnnotations: [
          for (final r in _series.lifts) VerticalRangeAnnotation(x1: r.fromS, x2: r.toS, color: c.liftGrey.withValues(alpha: 0.15)),
          for (final r in _series.signalLoss) VerticalRangeAnnotation(x1: r.fromS, x2: r.toS, gradient: _hatch(c.danger.withValues(alpha: 0.10))),
        ],
      ),
      extraLinesData: ExtraLinesData(
        verticalLines: [
          if (scrub != null) VerticalLine(x: scrub.elapsedS, color: c.ice, strokeWidth: 1),
        ],
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: AltitudeProfile.leftAxis,
            interval: axis.interval,
            getTitlesWidget: (v, meta) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(Fmt.metres(v, locale: l.code), style: AppText.label(c.textTertiary, size: 10), textAlign: TextAlign.right),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: AltitudeProfile.bottomAxis,
            interval: _series.timeInterval,
            getTitlesWidget: (v, meta) {
              if (v <= 0 || v >= meta.max) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(Fmt.durationCompact((v * 1000).round(), locale: l.code), style: AppText.label(c.textTertiary, size: 10)),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: widget.onScrub != null,
        handleBuiltInTouches: false,
        touchCallback: _onTouch,
        touchSpotThreshold: 40,
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: c.run,
          barWidth: 2,
          isCurved: false,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.run.withValues(alpha: 0.22), c.run.withValues(alpha: 0)],
            ),
          ),
        ),
      ],
    );

    return Semantics(
      label: s.chartLabel,
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: LineChart(data, duration: Duration.zero)),
              if (scrub != null)
                Positioned(
                  top: 0,
                  left: _chipLeft(box.maxWidth, scrub.elapsedS, maxX),
                  child: _ScrubReadout(
                    time: Fmt.timeOfDay(scrub.ts, locale: l.code),
                    altitude: Fmt.metres(scrub.altM, locale: l.code),
                    unit: s.unitM,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeps the readout over the cursor but inside the card.
  static double _chipLeft(double width, double elapsedS, double maxX) {
    const chip = 132.0;
    final plot = (width - AltitudeProfile.leftAxis).clamp(1.0, double.infinity);
    final x = AltitudeProfile.leftAxis + (elapsedS / maxX).clamp(0.0, 1.0) * plot;
    return (x - chip / 2).clamp(0.0, (width - chip).clamp(0.0, double.infinity));
  }

  /// Diagonal stripes so a signal-loss gap reads as "no data", not as a lift.
  static LinearGradient _hatch(Color color) => LinearGradient(
        begin: Alignment.topLeft,
        end: const Alignment(-0.92, -0.92),
        tileMode: TileMode.repeated,
        colors: [color, color, Colors.transparent, Colors.transparent],
        stops: const [0, 0.5, 0.5, 1],
      );
}

/// Floating glass chip above the ice cursor: "11:42 · 1.980 m".
class _ScrubReadout extends StatelessWidget {
  const _ScrubReadout({required this.time, required this.altitude, required this.unit});
  final String time, altitude, unit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: c.surfaceRaised.withValues(alpha: 0.94),
        shape: Squircle.border(Tokens.r10, side: c.glassStroke, width: c.hairlineWidth),
        shadows: Tokens.floatingShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(time, style: AppText.numXs(c.textPrimary)),
          Text(' · ', style: AppText.caption(c.textTertiary, size: 13)),
          Text(altitude, style: AppText.numXs(c.textPrimary)),
          const SizedBox(width: 4),
          Text(unit, style: AppText.unit(c.textTertiary, size: 11)),
        ],
      ),
    );
  }
}
