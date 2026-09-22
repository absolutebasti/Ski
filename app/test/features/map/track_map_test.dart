import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/app/widgets/widgets.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/features/map/map_sheet.dart';
import 'package:dropline/features/map/track_map.dart';
import 'package:dropline/features/recording/live_state_provider.dart';
import 'package:dropline/features/recording/live_track_provider.dart';

import '../../support/pump.dart';
import 'track_fixture.dart';

List<TrackPoint> threePoints() => [
      const TrackPoint(ts: 1000, lat: 47.4491, lon: 12.3913, accepted: true, state: MotionState.run),
      const TrackPoint(ts: 2000, lat: 47.4488, lon: 12.3910, accepted: true, state: MotionState.run),
      const TrackPoint(ts: 3000, lat: 47.4485, lon: 12.3906, accepted: true, state: MotionState.run),
    ];

Widget host(Widget child) => Scaffold(body: SizedBox(width: 400, height: 300, child: child));

Iterable<Polyline> polylinesOf(WidgetTester tester) =>
    tester.widgetList<PolylineLayer>(find.byType(PolylineLayer)).expand((l) => l.polylines);

void main() {
  testWidgets('TrackMap builds with 3 points without network', (tester) async {
    await pumpApp(tester, host(TrackMap(points: threePoints(), segments: const [], tilesEnabled: false)));
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    // glow + run
    expect(polylinesOf(tester).length, 2);
    // start + end markers
    expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer).first).markers.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('polylines are split by state: run glow + run + dashed lift', (tester) async {
    final pts = fixtureTrack();
    await pumpApp(tester, host(TrackMap(points: pts, segments: fixtureSegments(pts), tilesEnabled: false)));
    await tester.pump();
    final lines = polylinesOf(tester).toList();
    // 2 runs × (glow + line) + 1 lift
    expect(lines.length, 5);
    final lift = lines.where((p) => p.strokeWidth == TrackMap.liftWidth).toList();
    expect(lift.length, 1);
    expect(lift.single.pattern, isNot(const StrokePattern.solid()));
    expect(lines.where((p) => p.strokeWidth == TrackMap.glowWidth).length, 2);
    expect(lines.where((p) => p.strokeWidth == TrackMap.runWidth).length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrub marker snaps to the nearest point', (tester) async {
    final pts = fixtureTrack();
    await pumpApp(tester, host(TrackMap(points: pts, segments: const [], scrubTs: pts[70].ts + 300, tilesEnabled: false)));
    await tester.pump();
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer).first).markers;
    expect(markers.length, 3);
    expect(markers.last.point.latitude, closeTo(pts[70].lat!, 1e-9));
  });

  testWidgets('follow mode shows the puck fed from points and no end marker', (tester) async {
    final pts = fixtureTrack();
    await pumpApp(tester, host(TrackMap(points: pts, segments: const [], follow: true, tilesEnabled: false)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CurrentLocationLayer), findsOneWidget);
    expect(find.byType(LocationMarkerLayer), findsOneWidget);
    expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer).first).markers.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow mode throttles polyline rebuilds to 2 s', (tester) async {
    final pts = fixtureTrack();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final key = GlobalKey();
    Widget build(List<TrackPoint> p) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: host(TrackMap(key: key, points: p, segments: const [], follow: true, tilesEnabled: false))),
        );
    await tester.pumpWidget(build(pts.take(70).toList()));
    await tester.pump();
    final before = polylinesOf(tester).length; // lift + run glow + run
    expect(before, 3);

    // Grow the track immediately: the new run segment must NOT appear yet.
    await tester.pumpWidget(build(pts.take(180).toList()));
    await tester.pump();
    expect(polylinesOf(tester).length, before);

    // After the interval the timer fires and the second run is drawn.
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    expect(polylinesOf(tester).length, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MapSheetBody renders the live ring, the GPS pill and the readout', (tester) async {
    final pts = fixtureTrack();
    await pumpApp(
      tester,
      const Scaffold(body: MapSheetBody(tilesEnabled: false)),
      overrides: [
        liveTrackProvider.overrideWith(() => _SeededTrack(pts)),
        liveStateNotifierProvider.overrideWith(
          () => _SeededLive(const LiveState(speedMs: 12.5, altM: 1830, gps: GpsQuality.good, state: MotionState.run)),
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TrackMap), findsOneWidget);
    expect(find.text('Karte'), findsOneWidget);
    expect(find.text('45'), findsOneWidget); // 12.5 m/s → 45 km/h
    expect(find.text('1.830'), findsOneWidget);

    // GPS quality pill: three ice bars + the word
    expect(find.byType(GpsQualityPill), findsOneWidget);
    expect(find.text('GPS gut'), findsOneWidget);
    expect(GpsQualityPill.barsFor(GpsQuality.good), 3);
    expect(GpsQualityPill.barsFor(GpsQuality.weak), 1);
    expect(GpsQualityPill.barsFor(GpsQuality.none), 0);

    // state chip, not a Material Chip
    expect(find.text('Abfahrt 0'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);

    // the locate circle is a glyph circle with a semantics label now
    final locate = find.bySemanticsLabel('Auf mich zentrieren');
    expect(locate, findsOneWidget);
    await tester.tap(locate);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('MapSheetBody without a fix shows the waiting line and no hold button', (tester) async {
    await pumpApp(tester, const Scaffold(body: MapSheetBody(tilesEnabled: false)));
    await tester.pump();
    expect(find.text('Warte auf GPS …'), findsOneWidget);
    expect(find.byType(HoldToConfirmButton), findsNothing);
  });

  testWidgets('the inline hold-to-end finishes the day from the map', (tester) async {
    var ended = false;
    await pumpApp(
      tester,
      Scaffold(body: MapSheetBody(tilesEnabled: false, onEnd: () => ended = true)),
      overrides: [
        liveTrackProvider.overrideWith(() => _SeededTrack(fixtureTrack())),
        liveStateNotifierProvider.overrideWith(() => _SeededLive(const LiveState(speedMs: 8, altM: 1600, gps: GpsQuality.ok))),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final hold = find.byType(HoldToConfirmButton);
    expect(hold, findsOneWidget);
    expect(tester.getSize(hold).height, MapSheetBody.holdHeight);

    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(ended, isFalse); // not yet — it has to be held
    await tester.pump(const Duration(milliseconds: 1000));
    expect(ended, isTrue);
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _SeededTrack extends LiveTrackNotifier {
  _SeededTrack(this._pts);
  final List<TrackPoint> _pts;
  @override
  List<TrackPoint> build() => _pts;
}

class _SeededLive extends LiveStateNotifier {
  _SeededLive(this._s);
  final LiveState _s;
  @override
  LiveState build() => _s;
}
