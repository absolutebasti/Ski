import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/profile/altitude_profile.dart';
import 'package:slopetrack/features/profile/profile_series.dart';

import '../../support/pump.dart';
import '../days/golden_fonts.dart';

/// Axes and legend of the profile: '2.000 m' on the top label, clock time at
/// ¼ · ½ · ¾ of the day and the 10 pt legend row. Re-gold with
/// `flutter test test/features/profile --update-goldens`.
void main() {
  setUpAll(loadInterFonts);

  // 10:00 → 11:00, 1.700 m … 1.980 m, one lift ride and one signal gap.
  final t0 = DateTime(2026, 1, 15, 10).millisecondsSinceEpoch;
  final points = [
    for (var i = 0; i <= 3600; i += 10)
      TrackPoint(ts: t0 + i * 1000, lat: 47, lon: 12, accepted: true, fusedAltM: i < 1200 ? 1980 - i * 0.2 : i < 2400 ? 1740 + (i - 1200) * 0.2 : 1980 - (i - 2400) * 0.23),
  ];
  final segments = [
    Segment(id: 'r1', dayId: 'd', kind: SegmentKind.run, idx: 0, runNumber: 1, startTs: t0, endTs: t0 + 1200000),
    Segment(id: 'l1', dayId: 'd', kind: SegmentKind.lift, idx: 1, startTs: t0 + 1200000, endTs: t0 + 2400000),
    Segment(id: 'g1', dayId: 'd', kind: SegmentKind.signalLoss, idx: 2, startTs: t0 + 2400000, endTs: t0 + 2700000),
    Segment(id: 'r2', dayId: 'd', kind: SegmentKind.run, idx: 3, runNumber: 2, startTs: t0 + 2700000, endTs: t0 + 3600000),
  ];

  testWidgets('top label carries the unit, ticks are clock times, legend row present', (tester) async {
    tester.view.physicalSize = const Size(390, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('profile'),
          child: Padding(padding: const EdgeInsets.all(16), child: AltitudeProfile(points: points, segments: segments, height: 132)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final series = ProfileSeries.build(points, segments);
    expect(series.altitudeAxis.max, 2000);
    expect(find.text('2.000 m'), findsOneWidget);
    expect(find.text('2.000'), findsNothing);
    expect(find.text('1.700'), findsOneWidget);

    // Three clock ticks at ¼ · ½ · ¾: 10:15 · 10:30 · 10:45.
    for (final tick in ['10:15', '10:30', '10:45']) {
      expect(find.text(tick), findsOneWidget, reason: tick);
    }
    expect(find.text('10:00'), findsNothing);
    expect(find.text('11:00'), findsNothing);
    expect(find.textContaining(' min'), findsNothing, reason: 'no elapsed-time labels any more');

    // Legend row at 10 pt.
    expect(find.byType(ProfileLegend), findsOneWidget);
    for (final label in ['Abfahrt', 'Lift', 'Signalverlust']) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(tester.widget<Text>(find.text(label)).style?.fontSize, 10);
    }
    final legend = tester.getRect(find.byType(ProfileLegend));
    final chart = tester.getRect(find.byType(AltitudeProfile));
    expect(legend.top, greaterThanOrEqualTo(chart.top + 132));

    await expectLater(find.byKey(const ValueKey('profile')), matchesGoldenFile('goldens/altitude_profile_axes.png'));
  });

  testWidgets('the legend omits Signalverlust when the day has no gap', (tester) async {
    await pumpApp(tester, Padding(padding: const EdgeInsets.all(16), child: AltitudeProfile(points: points, segments: segments.where((s) => s.kind != SegmentKind.signalLoss).toList())));
    await tester.pump();
    expect(find.text('Abfahrt'), findsOneWidget);
    expect(find.text('Lift'), findsOneWidget);
    expect(find.text('Signalverlust'), findsNothing);
  });

  test('clockInterval splits the day in quarters', () {
    final s = ProfileSeries.build(points, segments);
    expect(s.durationS, 3600);
    expect(s.clockInterval, 900);
  });
}
