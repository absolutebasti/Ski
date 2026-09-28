import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/days/resort_picker.dart';

import '../../support/pump.dart';
import 'day_fixtures.dart';

void main() {
  test('ranked() sorts nearest-first when a point is known', () {
    // Just outside Kitzbühel: Kitzbühel < Ischgl < Zermatt.
    final r = ResortPickerSheet.ranked(fixtureResorts, lat: 47.45, lon: 12.40);
    expect(r.map((e) => e.$1.id).toList(), ['kitzbuehel', 'ischgl', 'zermatt']);
    expect(r.first.$2, lessThan(2000));
    expect(r.last.$2, greaterThan(300000));
  });

  test('ranked() falls back to alphabetical without a point', () {
    final r = ResortPickerSheet.ranked(fixtureResorts);
    expect(r.map((e) => e.$1.name).toList(), ['Ischgl', 'Kitzbühel', 'Zermatt']);
    expect(r.every((e) => e.$2 == null), isTrue);
  });

  testWidgets('the sheet filters by name and returns the tapped resort', (tester) async {
    ResortPick? picked;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                picked = await ResortPickerSheet.show(context, resorts: fixtureResorts, lat: 47.45, lon: 12.40, currentId: 'kitzbuehel');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Skigebiet ändern'), findsOneWidget);
    expect(find.text('Freies Gelände'), findsOneWidget);
    // nearest first
    final kitz = tester.getTopLeft(find.text('Kitzbühel'));
    final zermatt = tester.getTopLeft(find.text('Zermatt'));
    expect(kitz.dy, lessThan(zermatt.dy));
    expect(find.textContaining('km'), findsNWidgets(3));

    await tester.enterText(find.byKey(const ValueKey('resort-picker-search')), 'zer');
    await tester.pump();
    expect(find.text('Kitzbühel'), findsNothing);
    expect(find.text('Freies Gelände'), findsNothing);
    expect(find.text('Zermatt'), findsOneWidget);

    await tester.tap(find.text('Zermatt'));
    await tester.pumpAndSettle();
    expect(picked?.resort?.id, 'zermatt');
  });

  testWidgets('Freies Gelände returns a pick without a resort; no match shows the empty line', (tester) async {
    ResortPick? picked;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await ResortPickerSheet.show(context, resorts: fixtureResorts);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('resort-picker-search')), 'xyz');
    await tester.pump();
    expect(find.text('Kein Skigebiet gefunden.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('resort-picker-search')), '');
    await tester.pump();
    await tester.tap(find.text('Freies Gelände'));
    await tester.pumpAndSettle();
    expect(picked, isNotNull);
    expect(picked!.resort, isNull);
  });
}
