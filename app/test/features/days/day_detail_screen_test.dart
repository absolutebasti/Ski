import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:schwung/app/widgets/widgets.dart';
import 'package:schwung/core/core.dart';
import 'package:schwung/data/db/providers.dart';
import 'package:schwung/features/days/day_detail_screen.dart';
import 'package:schwung/features/days/run_list.dart';
import 'package:schwung/features/days/stats_grid.dart';
import 'package:schwung/features/map/track_map.dart';
import 'package:schwung/features/profile/altitude_profile.dart';

import '../../support/pump.dart';
import 'day_fixtures.dart';

const _dayId = '0192abcd-0000-7000-8000-0000000000aa';

List<Override> overrides(DayDetail detail, {RecordingRepository? repo}) => [
      dayDetailProvider.overrideWith((ref, id) => detail),
      if (repo != null) daysRepositoryProvider.overrideWithValue(repo),
    ];

/// The whole screen at once — otherwise the lazy list never builds the runs.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders header, map, profile, time bar, stats grid and run rows', (tester) async {
    useTallSurface(tester);
    final detail = syntheticDayDetail();
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(detail),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Kitzbühel'), findsOneWidget);
    expect(find.text(Fmt.dateLong(detail.day.startedAt, locale: 'de')), findsOneWidget);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.byType(AltitudeProfile), findsOneWidget);
    expect(find.byType(StackedTimeBar), findsOneWidget);
    expect(find.textContaining('Gesamt '), findsOneWidget);

    // eight stat tiles, in the order of PLAN §3
    expect(find.byType(StatsGrid), findsOneWidget);
    expect(find.byType(StatTile), findsNWidgets(8));
    expect(find.text('SKI-KM'), findsOneWidget);
    expect(find.text('LIFT-KM'), findsOneWidget);
    expect(find.text('AUFSTIEG'), findsOneWidget);
    expect(find.text('Ø SPEED BEIM SKIFAHREN'), findsOneWidget);
    expect(find.text('HÖCHSTER/TIEFSTER PUNKT'), findsOneWidget);
    expect(find.text('LIFTE'), findsOneWidget);

    // run rows: 'Abfahrt 1 · 09:21 · 312 hm · 2,1 km · 61 km/h · 14 %'
    expect(find.byType(RunList), findsOneWidget);
    final runs = detail.runs.toList();
    expect(runs, isNotEmpty);
    expect(find.textContaining('Abfahrt 1 · '), findsOneWidget);
    for (final r in runs) {
      expect(find.textContaining('${r.runNumber} · ${Fmt.timeOfDay(r.startTs, locale: 'de')} · '), findsOneWidget);
    }
    expect(find.text('Teilen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrubbing the altitude profile moves the map marker', (tester) async {
    useTallSurface(tester);
    final detail = syntheticDayDetail();
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(detail),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widget<TrackMap>(find.byType(TrackMap)).scrubTs, isNull);
    final ts = detail.points[detail.points.length ~/ 2].ts;
    tester.widget<AltitudeProfile>(find.byType(AltitudeProfile)).onScrub!(ts);
    await tester.pump();
    expect(tester.widget<TrackMap>(find.byType(TrackMap)).scrubTs, ts);

    tester.widget<AltitudeProfile>(find.byType(AltitudeProfile)).onScrub!(null);
    await tester.pump();
    expect(tester.widget<TrackMap>(find.byType(TrackMap)).scrubTs, isNull);
  });

  testWidgets('Teilen offers the card and the GPX', (tester) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(syntheticDayDetail()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Teilen'));
    await tester.pumpAndSettle();
    expect(find.text('Bild teilen'), findsOneWidget);
    expect(find.text('GPX teilen'), findsOneWidget);
  });

  testWidgets('Löschen asks once and then soft-deletes', (tester) async {
    useTallSurface(tester);
    final repo = RecordingRepository();
    addTearDown(() async => repo.db.close());
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(syntheticDayDetail(), repo: repo),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Skitag löschen?'), findsOneWidget);
    expect(repo.deleted, isEmpty);

    await tester.tap(find.text('Löschen').last);
    await tester.pumpAndSettle();
    expect(repo.deleted, [_dayId]);
  });

  testWidgets('weather glyph and temperature come from the stored snapshot', (tester) async {
    useTallSurface(tester);
    final detail = syntheticDayDetail(weatherJson: '{"fetchedAt":1,"tempSummitC":-4.0,"wmoCode":71}');
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(detail),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
    expect(find.text('−4°'), findsOneWidget);
  });

  testWidgets('a broken weather blob is ignored, not thrown', (tester) async {
    useTallSurface(tester);
    final detail = syntheticDayDetail(weatherJson: 'not json');
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(detail),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Kitzbühel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown day shows the error line instead of crashing', (tester) async {
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: 'nope', tilesEnabled: false),
      overrides: [dayDetailProvider.overrideWith((ref, id) => throw StateError('day nope not found'))],
    );
    await tester.pump();
    expect(find.text('Der Tag konnte nicht geladen werden.'), findsOneWidget);
  });
}
