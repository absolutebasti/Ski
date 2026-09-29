import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/summary/tagesbilanz_screen.dart';

import '../../support/pump.dart';
import '../days/golden_fonts.dart';

/// The REKORD card at its fixed 76 pt: the overline + line pair sits in the
/// vertical middle of the card, not hugging the top edge. Re-gold with
/// `flutter test test/features/summary --update-goldens`.
void main() {
  setUpAll(loadInterFonts);

  testWidgets('RecordCard centres its content in the 76 pt card', (tester) async {
    tester.view.physicalSize = const Size(375, 140);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const Scaffold(
        body: RepaintBoundary(
          key: ValueKey('record'),
          child: Padding(padding: EdgeInsets.all(20), child: RecordCard(pbs: [Pb.topSpeed])),
        ),
      ),
    );
    await tester.pump();

    final card = tester.getRect(find.byType(RecordCard));
    expect(card.height, 76);
    final overline = tester.getRect(find.text('REKORD'));
    final line = tester.getRect(find.text('Schnellster Tag der Saison'));
    final contentCentre = (overline.top + line.bottom) / 2;
    expect(contentCentre, closeTo(card.center.dy, 2), reason: 'content top ${overline.top}, bottom ${line.bottom}, card $card');
    expect(overline.top - card.top, greaterThan(12), reason: 'must not hug the top edge');
    expect(tester.takeException(), isNull);

    await expectLater(find.byKey(const ValueKey('record')), matchesGoldenFile('goldens/record_card_76.png'));
  });
}
