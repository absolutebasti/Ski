import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/app/widgets/widgets.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/data/db/providers.dart';
import 'package:dropline/features/days/day_detail_screen.dart';
import 'package:dropline/features/days/run_list.dart';
import 'package:dropline/features/days/stats_grid.dart';
import 'package:dropline/features/map/thumbnail_renderer.dart';
import 'package:dropline/features/map/track_map.dart';
import 'package:dropline/features/profile/altitude_profile.dart';

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

/// A phone-sized surface, so the map hero can actually collapse.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders the map hero, the 3-up, profile, time bar, stat grid and run rows', (tester) async {
    useTallSurface(tester);
    final detail = syntheticDayDetail();
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(detail),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // hero plate: date 22 + resort
    expect(find.text('Kitzbühel'), findsOneWidget);
    expect(find.text(Fmt.dateLong(detail.day.startedAt, locale: 'de')), findsOneWidget);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.byType(AltitudeProfile), findsOneWidget);
    expect(find.text('HÖHENPROFIL'), findsOneWidget);

    // time card: overline left, total tabular right
    expect(find.byType(StackedTimeBar), findsOneWidget);
    expect(find.text('ZEIT'), findsOneWidget);
    expect(find.text(Fmt.durationCompact(detail.day.stats.elapsedMs, locale: 'de')), findsOneWidget);

    // 3-up hero numbers at 44
    expect(find.text('HÖHENMETER'), findsOneWidget);
    expect(find.text('TOP-SPEED'), findsOneWidget);

    // eight stat tiles, in the order of DESIGN §5
    expect(find.byType(StatsGrid), findsOneWidget);
    expect(find.byType(StatTile), findsNWidgets(8));
    expect(find.text('SKI-KM'), findsOneWidget);
    expect(find.text('LIFT-KM'), findsOneWidget);
    expect(find.text('AUFSTIEG'), findsOneWidget);
    expect(find.text('Ø SPEED'), findsOneWidget);
    expect(find.text('HOCH/TIEF'), findsOneWidget);
    expect(find.text('LIFTE'), findsOneWidget);

    // run table: '#1' + clock, then three tabular columns
    expect(find.byType(RunList), findsOneWidget);
    final runs = detail.runs.toList();
    expect(runs, isNotEmpty);
    expect(find.text('#1'), findsOneWidget);
    for (final r in runs) {
      expect(find.text('#${r.runNumber}'), findsOneWidget);
      expect(find.text(Fmt.timeOfDay(r.startTs, locale: 'de')), findsWidgets);
    }
    expect(find.text('Teilen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the map hero collapses into the 52 pt bar on scroll', (tester) async {
    usePhoneSurface(tester);
    final detail = syntheticDayDetail();
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(detail),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final date = Fmt.dateLong(detail.day.startedAt, locale: 'de');
    // expanded: the glass plate carries the date at 22
    expect(tester.widget<Text>(find.text(date)).style!.fontSize, 22);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();

    // collapsed: the plate is gone, the bar title is the 19 pt displayS
    expect(tester.widget<Text>(find.text(date)).style!.fontSize, 19);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Tage row thumbnail flies into the map hero (tag route-<dayId>)', (tester) async {
    usePhoneSurface(tester);
    final detail = syntheticDayDetail();
    final nav = GlobalKey<NavigatorState>();
    await pumpApp(
      tester,
      Navigator(
        key: nav,
        // MaterialApp installs one for its own navigator; a nested one needs it too.
        observers: [HeroController()],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Center(
              child: Hero(tag: 'route-$_dayId', child: const SizedBox(width: 84, height: 84)),
            ),
          ),
        ),
      ),
      overrides: overrides(detail),
    );
    await tester.pump();

    unawaited(nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // mid-flight the shuttle draws the route itself instead of flying a map
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TrackThumbnailPainter),
      findsWidgets,
    );

    await tester.pumpAndSettle();
    expect(find.byType(TrackMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a day without points falls back to the typeset contour hero', (tester) async {
    useTallSurface(tester);
    final full = syntheticDayDetail();
    final detail = DayDetail(day: full.day, segments: full.segments, points: const []);
    await pumpApp(
      tester,
      const DayDetailScreen(dayId: _dayId, tilesEnabled: false),
      overrides: overrides(detail),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('OHNE TRACK'), findsOneWidget);
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
    expect(find.text('Tag teilen'), findsOneWidget);
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
