import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/settings/licences_page.dart';

import '../../support/pump.dart';

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('lists every data and font source with its licence', (tester) async {
    tall(tester);
    await pumpApp(tester, const LicencesPage());
    await tester.pump();
    for (final src in LicencesPage.sources) {
      expect(find.text(src.$1), findsOneWidget);
    }
    expect(find.textContaining('ODbL'), findsOneWidget);
    expect(find.textContaining('CC BY 4.0'), findsOneWidget);
    expect(find.textContaining('Open Font License'), findsOneWidget);
    expect(find.text('Alle Paket-Lizenzen'), findsOneWidget);
  });

  testWidgets('the package licences button opens Flutter\'s licence page', (tester) async {
    tall(tester);
    await pumpApp(tester, const LicencesPage());
    await tester.pump();
    await tester.tap(find.text('Alle Paket-Lizenzen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
