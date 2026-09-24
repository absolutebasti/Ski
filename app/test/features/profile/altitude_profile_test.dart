import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/profile/altitude_profile.dart';
import 'package:slopetrack/features/profile/profile_series.dart';

import '../../support/pump.dart';
import '../share/synthetic_detail.dart';

void main() {
  final detail = syntheticDetail();

  group('ProfileSeries', () {
    test('keeps every point below the cap and shades lifts', () {
      final s = ProfileSeries.build(detail.points, detail.segments);
      expect(detail.points.length, greaterThan(ProfileSeries.maxSamples), reason: 'fixture should exercise the downsampler');
      expect(s.samples.length, lessThanOrEqualTo(ProfileSeries.maxSamples));
      expect(s.samples.length, greaterThan(1000));
      expect(s.samples.last.ts, detail.points.last.ts);
      expect(s.samples.first.elapsedS, 0);
      expect(s.lifts.length, detail.lifts.length);
      expect(s.signalLoss, isEmpty);
      for (final r in s.lifts) {
        expect(r.toS, greaterThan(r.fromS));
        expect(r.toS, lessThanOrEqualTo(s.durationS));
      }
      final axis = s.altitudeAxis;
      expect(axis.min, lessThanOrEqualTo(s.minAltM));
      expect(axis.max, greaterThanOrEqualTo(s.maxAltM));
      expect(s.timeInterval, 600);
    });

    test('downsamples 5 000 points to ≤ 1 500 while keeping the extremes', () {
      const t0 = 1700000000000;
      final pts = [
        for (var i = 0; i < 5000; i++)
          TrackPoint(ts: t0 + i * 1000, lat: 47, lon: 12, accepted: true, fusedAltM: i == 2345 ? 3000 : i == 4321 ? 100 : 1000 + (i % 50).toDouble()),
      ];
      final s = ProfileSeries.build(pts, const []);
      expect(s.samples.length, lessThanOrEqualTo(ProfileSeries.maxSamples));
      expect(s.samples.length, greaterThan(1000));
      expect(s.maxAltM, 3000);
      expect(s.minAltM, 100);
      expect(s.samples.first.ts, t0);
      expect(s.samples.last.ts, t0 + 4999 * 1000);
      for (var i = 1; i < s.samples.length; i++) {
        expect(s.samples[i].ts, greaterThan(s.samples[i - 1].ts));
      }
      expect(s.nearest(2345)!.altM, 3000);
    });

    test('shades signal-loss gaps separately from lifts', () {
      const t0 = 1700000000000;
      final pts = [
        for (var i = 0; i < 600; i++) TrackPoint(ts: t0 + i * 1000, lat: 47, lon: 12, accepted: true, fusedAltM: 2000 - i.toDouble()),
      ];
      const segs = [
        Segment(id: 'a', dayId: 'd', kind: SegmentKind.run, idx: 0, runNumber: 1, startTs: t0, endTs: t0 + 200000),
        Segment(id: 'b', dayId: 'd', kind: SegmentKind.signalLoss, idx: 1, startTs: t0 + 200000, endTs: t0 + 260000),
        Segment(id: 'c', dayId: 'd', kind: SegmentKind.lift, idx: 2, startTs: t0 + 260000, endTs: t0 + 400000),
        Segment(id: 'd', dayId: 'd', kind: SegmentKind.stop, idx: 3, startTs: t0 + 400000, endTs: t0 + 420000),
      ];
      final s = ProfileSeries.build(pts, segs);
      expect(s.lifts, hasLength(1));
      expect(s.lifts.single.fromS, 260);
      expect(s.lifts.single.toS, 400);
      expect(s.signalLoss, hasLength(1));
      expect(s.signalLoss.single.fromS, 200);
      expect(s.signalLoss.single.toS, 260);
    });

    test('ignores rejected points and points without altitude', () {
      const t0 = 1700000000000;
      const pts = [
        TrackPoint(ts: t0, accepted: true, fusedAltM: 1000),
        TrackPoint(ts: t0 + 1000, accepted: false, fusedAltM: 5000),
        TrackPoint(ts: t0 + 2000, accepted: true),
        TrackPoint(ts: t0 + 3000, accepted: true, fusedAltM: 1100),
      ];
      final s = ProfileSeries.build(pts, const []);
      expect(s.samples.length, 2);
      expect(s.maxAltM, 1100);
      expect(ProfileSeries.build(const [], const []).isEmpty, isTrue);
    });
  });

  group('AltitudeProfile', () {
    testWidgets('builds a LineChart from > 500 synthetic points', (tester) async {
      await pumpApp(tester, Padding(padding: const EdgeInsets.all(20), child: AltitudeProfile(points: detail.points, segments: detail.segments, onScrub: (_) {})));
      expect(find.byType(LineChart), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.single.spots.length, greaterThan(500));
      expect(chart.data.lineBarsData.single.spots.length, lessThanOrEqualTo(1500));
      expect(chart.data.rangeAnnotations.verticalRangeAnnotations.length, detail.lifts.length);
      expect(chart.data.lineBarsData.single.belowBarData.show, isTrue, reason: 'area fill under the profile');
      expect(chart.data.lineBarsData.single.belowBarData.gradient, isNotNull, reason: 'accent 22 % → 0 area gradient');
      expect(chart.data.lineBarsData.single.barWidth, 2);
      expect(chart.data.extraLinesData.verticalLines, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the empty line when there are no points', (tester) async {
      await pumpApp(tester, const AltitudeProfile(points: [], segments: []));
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Kein Höhenprofil'), findsOneWidget);
    });

    testWidgets('dragging reports a timestamp inside the day and null on release', (tester) async {
      final seen = <int?>[];
      await pumpApp(tester, Padding(padding: const EdgeInsets.all(20), child: AltitudeProfile(points: detail.points, segments: detail.segments, onScrub: seen.add)));
      final chart = find.byType(LineChart);
      final center = tester.getCenter(chart);
      final g = await tester.startGesture(center);
      await tester.pump();
      await g.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(seen.whereType<int>(), isNotEmpty);
      final ts = seen.whereType<int>().last;
      expect(ts, inInclusiveRange(detail.points.first.ts, detail.points.last.ts));
      final cursor = tester.widget<LineChart>(chart).data.extraLinesData.verticalLines;
      expect(cursor, hasLength(1));
      expect(cursor.single.strokeWidth, 1, reason: '1 px ice cursor');
      expect(cursor.single.color, AppColors.dark.ice);
      // floating glass readout: '11:42 · 1.980 m'
      expect(find.text(Fmt.timeOfDay(ts, locale: 'de')), findsOneWidget);
      expect(find.text('·'), findsNothing);
      expect(find.text(' · '), findsOneWidget);
      expect(find.text('m'), findsOneWidget);
      await g.up();
      await tester.pump();
      expect(seen.last, isNull);
      expect(tester.widget<LineChart>(chart).data.extraLinesData.verticalLines, isEmpty);
      expect(find.text(' · '), findsNothing);
    });
  });
}
