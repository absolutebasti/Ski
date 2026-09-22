import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/features/days/day_card.dart';
import 'package:dropline/features/map/thumbnail_renderer.dart';

import '../../support/pump.dart';
import 'day_fixtures.dart';

void main() {
  testWidgets('a day without a thumbnail file falls back to the placeholder', (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: DayCard(day: summary(id: 'a', startedAt: tsThisSeason, mapThumbPath: '/does/not/exist.png'))),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(ContourPattern), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rendered map PNG is shown on the card', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('dropline-days-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File('${tmp.path}/thumb.png');

    await tester.runAsync(() async {
      final png = await ThumbnailRenderer.renderPng(syntheticDayDetail(), width: 120, height: 80);
      await file.writeAsBytes(png, flush: true);
    });

    await pumpApp(
      tester,
      Scaffold(body: DayCard(day: summary(id: 'a', startedAt: tsThisSeason, mapThumbPath: file.path))),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.downhill_skiing_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no resort falls back to "Freies Gelände"', (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: DayCard(day: summary(id: 'a', startedAt: tsThisSeason, resortName: null))),
    );
    await tester.pump();
    expect(find.text('Freies Gelände'), findsOneWidget);
  });
}
